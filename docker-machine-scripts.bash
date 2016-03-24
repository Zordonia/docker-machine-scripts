#!/usr/bin/env bash

# Helper function for determining if an array contains an element.
# Stolen mercilessly from: http://stackoverflow.com/questions/3685970/check-if-an-array-contains-a-value
containsElement () {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}

# Helper function to select values (based on the reference array passed in)
# Also allows a default, and a custom prompt
sel-values() {
  # Declare variables
  local ltcyan=$'\e[1;36m'
  local reset_color=$'\e[m'
  local default=$2
  local prompt=$3
  if [ "$3" == "" ]
  then
    prompt="Please select from the above options:"
  fi
  local opts=$1[@]
  local options=("${!opts}")
  local options_str=$options
  if [ "$options" == "" ]
  then
    options=()
  else
    options=($options)
  fi
  # Default result to options
  final_result=$options
  cnt=${#options[@]}
  # If we have no options, no result.
  if [ $cnt == 0 ]
  then
    final_result=""
  else
    # If we have one option, short-circuit
    if [ $cnt == 1 ]
    then
      final_result=$options
    else
      # Check if our default is in options, if not add it (if un-empty)
      containsElement "$default" "${opts}"
      if [ "$?" != "0" ] && [ "$default" != "" ]
      then
        options=("$default" $options_str "Cancel")
      else
        options=($options_str "Cancel")
      fi
      # Set our prompt
      PS3="${ltcyan}$prompt${reset_color}"
      # Prompt for selection
      select opt in "${options[@]}"
      do
        # Set result to selection
        final_result=$opt
        break
      done
    fi
  fi
  # Print result (function-return)
  echo $final_result
}

# Helper function for selecting a docker-machine.
docker-machine-sel() {
  # Declare local variables
  local default="$2"
  local prompt="$1"
  if [ "$prompt" == "" ]
  then
    prompt='Select a docker-machine: '
  fi
  # Get list of docker machines currently created
  machines=$(docker-machine ls | awk '{if ($1 != "NAME") print $1;}')
  # Turn into a one liner
  machines=${machines//$'\n'/ }
  # Turn into array
  array=("$machines")
  if [ "$DOCKER_MACHINE_DEFAULT" != "" ]
  then
    if [ "$default" == "" ]
    then
      array=("$machines Clear")
    fi
  fi
  # echo selection (return-value)
  echo "$(sel-values array "$default" "$prompt")"
}

# Helper function to set the default value for docker-machine
# so that you are not prompted every time. 
# (NOTE: you can set the env variable DOCKER_MACHINE_DEFAULT to do this as well)
docker-machine-default() {
  printf "Current default: $DOCKER_MACHINE_DEFAULT\n"
  result=$(docker-machine-sel "Select a docker-machine as default: ")
  if [ "$result" == "Clear" ]
  then
    printf "\e[91m\e[1mCleared DOCKER_MACHINE_DEFAULT\e[0m\n"
    DOCKER_MACHINE_DEFAULT=
  elif [ "$result" == "Cancel" ]
  then
    printf "\e[91m\e[1mDefault selection canceled.\e[0m\n"
  else
    DOCKER_MACHINE_DEFAULT=$result
    printf "\e[35mTo avoid this prompt in the future add the following to your bash profile:\e[0m\n"
    printf "DOCKER_MACHINE_DEFAULT=$DOCKER_MACHINE_DEFAULT\n"
  fi
}

# Helper function to use the default docker machine or; if not set to 
# select a docker machine (provides option to set as default)
docker-machine-default-or-sel() {
  docker_util_result=
  local m=$1
  if [ “$1” == “” ]
  then
    if [ "$DOCKER_MACHINE_DEFAULT" == "" ]
    then
      m=$(docker-machine-sel "No default machine specified, please select machine: ")
      if [ "$m" == "" ] || [ "$m" == "Cancel" ]
      then
        echo "Action canceled or no docker-machine selected."
        return 1
      fi
      yes_no=("Yes No")
      set_as_default=$(sel-values yes_no "" "Would you like to set this as default? ")
      if [ "$set_as_default" == "Yes" ]
      then
        DOCKER_MACHINE_DEFAULT=$m
      elif [ "$set_as_default" == "Cancel" ]
      then
        return 1
      fi
    else
      printf "\e[33mUsing default: $DOCKER_MACHINE_DEFAULT\e[0m\n"
      m=$DOCKER_MACHINE_DEFAULT
    fi
  fi
  docker_util_result=$m
}

CERTIFICATE_FILE_LOC=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../ca.crt
# Will use default machine if set, or prompt for selection.
# Starts the docker machine and provisions the keys
docker-machine-up() {
  docker-machine-default-or-sel $1
  local m=$docker_util_result
  if [ "$m" == "" ] || [ "$m" == "Cancel" ]
  then
    return 1
  fi
  m=$(echo $m  | tail -n1)
  printf "Starting docker machine $m\n"
  docker-machine start $m
  eval "$(docker-machine env $m)"
  docker-machine scp $CERTIFICATE_FILE_LOC $m:/tmp/ca.crt
  docker-machine ssh $m "sudo mkdir -p /etc/docker/certs.d/registry2.bn.co"
  docker-machine ssh $m "sudo cp /tmp/ca.crt /etc/docker/certs.d/registry2.bn.co/"
}

docker-compose-hosts() {
  docker-machine-default-or-sel $1
  local m=$docker_util_result
  if [ "$m" == "" ] || [ "$m" == "Cancel" ]
  then
    return 1
  fi
  m=$(echo $m  | tail -n1)
  printf "Modifying hosts file to adhere to docker-compose.yml file.\n"
  lead='^### BEGIN DOCKER COMPOSE HOST LIST ###$'
  tail='^### END DOCKER COMPOSE HOST LIST ###$'

  docker_machine_ip=$(docker-machine ip $m)

  dockerhosts=$(grep '^\S*:$' docker-compose.yml  | rev | cut -c 2- | rev | awk -v ip=$docker_machine_ip '{printf ip" "$0"\n"}' > dockerhosts.tmp)

  sudo sed -i '' -e "/$lead/,/$tail/{ /$lead/{p; r dockerhosts.tmp
          }; /$tail/p; d; }"  /etc/hosts

  rm dockerhosts.tmp
}

docker-compose-hosts-init() {
  echo -e '### BEGIN DOCKER COMPOSE HOST LIST ###\n### END DOCKER COMPOSE HOST LIST ###\n' | sudo tee -a /etc/hosts
}

# Helper function for selecting a docker container from a docker machine
# Will use default machine if set, or will prompt for selection.
# Will prompt for selection of docker-containers (including All)
docker-machine-sel-ps() {
  docker-machine-up
  first=$1
  if [ "$first" != "no-opts" ]
  then
    containers=$(docker ps -a -q | awk '{if ($1 != "CONTAINER") print $1;}')
  else
    containers=$(docker ps -q | awk '{if ($1 != "CONTAINER") print $1;}')
  fi
  if [ "$first" != "" ] && [ "$first" != "no-opts" ]
  then
    docker_util_result=$1
    return 0
  fi
  # Turn into a one liner
  containers=${containers//$'\n'/ }
  # Turn into array
  array=("$containers")
  # Set default machine
  docker_util_result="$(sel-values array "All" "Select a container: ")"
}

docker-machine-sel-ps-running() {
  docker-machine-up
  first=$1
  containers=$(docker ps | awk '{if ($1 != "CONTAINER") print $NF;}')
  if [ "$first" != "" ] && [ "$first" != "no-opts" ]
  then
    docker_util_result=$1
    return 0
  fi
  # Turn into a one liner
  containers=${containers//$'\n'/ }
  # Turn into array
  array=("$containers")
  # Set default machine
  docker_util_result="$(sel-values array "All" "Select a container: ")"
}

# Function for stopping (and subsequently removing All or 1 container)
# Will use default docker machine or prompt for selection.
# Will prompt for selection of docker container.
docker-clean() {
  docker-machine-sel-ps $1
  local ps=$docker_util_result
  if [ "$ps" == "All" ]
  then
    echo "Stopping everything."
    docker stop $(docker ps -a -q)
    echo "Removing everything."
    docker rm $(docker ps -a -q)
  elif [ "$ps" == "" ]
  then
    echo "No container selected."
    return 0
  elif [ "$ps" == "Cancel" ]
  then
    echo "Clean canceled."
    return 0
  else
    echo "Stopping $ps"
    docker stop "$ps"
    echo "Removing $ps"
    docker rm "$ps"
  fi
}

docker-clean-all() {
  docker stop $(docker ps -a -q)
  docker rm $(docker ps -a -q)

  docker rmi -f $(docker images -q)
  docker rmi -f $(docker images -q)

  docker volume ls | grep -o local | wc -l
  docker volume rm $(docker volume ls -q)
}

# Function for changing docker-machines
docker-machine-change() {
  docker-machine-default-or-sel $1
  local m=$docker_util_result
  if [ "$m" == "" ]
  then
    return 1
  fi
  docker-machine-up "$m"
}

# Function for restarting docker machine.
# Will kill and start (and provision) the default machine (or prompt for selection.)
docker-machine-restart() {
  docker-machine-default-or-sel $1
  local m=$docker_util_result
  if [ "$m" == "" ]
  then
    return 1
  fi
  docker-machine kill $m
  docker-machine start $m
  eval "$(docker-machine env $m)"
}

# Function for "ssh"-ing into docker container.
docker-ssh() {
  opts=$1
  if [ "$1" == "" ]
  then
    opts="no-opts"
  fi
  docker-machine-sel-ps-running $opts
  local ps=$docker_util_result
  if [ "$ps" == "Cancel" ]
  then
    return 0
  elif [ "$ps" == "All" ]
  then
    printf "\e[91m\e[1mCannot ssh into every thing.\e[0m\n"
    return 1
  elif [ "$ps" == "" ]
  then
    printf "\e[91m\e[1mCannot find containers:\n$(docker ps)\e[0m\n"
    return 1
  fi
  docker exec -i -t $ps bash
}

docker-login () {
  eval $(AWS_PROFILE=bnproducts aws ecr get-login)
}

docker-move () {
  registry2="$1"
  docker pull $registry2

  repo_name=$(echo $registry2 | awk '{gsub("registry2.bn.co/","", $0); printf $0;}')
  tagless=$(echo $repo_name | awk '{gsub(":.*$","", $0); printf $0;}')

  docker tag $registry2 396514920776.dkr.ecr.us-east-1.amazonaws.com/$repo_name
  AWS_PROFILE=bnproducts aws ecr create-repository --region us-east-1 --repository-name $tagless
  docker push 396514920776.dkr.ecr.us-east-1.amazonaws.com/$repo_name
}
