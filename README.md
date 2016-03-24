## Using utility scripts

The docker-machine-scripts.bash file contains useful scripts for docker-machine

### Source the script file

    source docker-machine-scripts.bash

OR add the source to your ~/.bash_profile 

    #!/usr/bin/env bash
    ...
    source ~/path/to/repository/docker-machine-scripts.bash

### Adding default docker-machine

    DOCKER_MACHINE_DEFAULT=dev

OR add the default to your ~/.bash_profile

    #!/usr/bin/env bash
    ...
    DOCKER_MACHINE_DEFAULT=dev

### Changing Script File Location

The bash script assumes that you've pulled the repository and sourced the docker-machine-scripts file. It will automatically pull in the ca.crt file into your docker-machine via `docker-machine-up`. If however you have just pulled the bash file itself and not the full repository, you'll have to change the CERTIFICATE_FILE_LOC environment variable in the script to the location of your certificates.

### Commands

There are a few commands in the script that are just utility commands for the rest. You can feel free to ignore them as they are superfluous to the real goal of the scripts (to make using docker-machine easier)

Each of these scripts will use your default docker-machine or will prompt you to select one if it is not set.

Here are the useful commands:

#### docker-machine-default 

- Sets the default docker-machine environment variable for use with the rest of these scripts. You'll likely be working with a single docker-machine vm, so setting this once and forgetting it in your bash_profile is recommended. It does provide the utility to clear the variable so that you can easily use the scripts with another docker-machine.

#### docker-machine-up 

- Will start the machine and then provision the ca certs file. 

  Replaces the following scripts: 

    docker-machine start {default-machine}
    eval "$(docker-machine env {default-machine})"

  Usage:

    docker-machine-up machine-name (named)
    docker-machine-up (default - or prompt)

#### docker-machine-restart 

- Will restart your docker-machine (and provision the ca certs file).

  Replaces the following scripts: 

    docker-machine kill {default-machine}
    docker-machine start {default-machine}
    eval "$(docker-machine env {default-machine})"

  Usage:

    docker-machine-restart machine-name (named)
    docker-machine-restart (default - or prompt)

#### docker-clean 

- Will stop and remove the provided container id. Or will prompt you to select a container. You may also select "All" to stop and remove all docker containers on the selected machine.

  Replaces the following scripts: 

    docker stop {container-id}
    docker rm {container-id}

#### docker-ssh 

- Will "ssh" (exec bash) on the selected container id. Can provide a (partial) container id or select one from the prompt.

  Replaces the following scripts:

    docker exec -it {container-id} bash

  Usage:

    docker-ssh container-id (using id)
    docker-ssh (default machine or prompt -> prompt for container id)

#### docker-machine-change 

- Will change your current active docker machine to the provided argument (or will change back to default if no argument provided).

  Usage:

    docker-machine-change machine-name (machine-name is now active)
    docker-machine-change (default or prompt is now active)

#### docker-compose-hosts

- Will modify your /etc/hosts file with hosts from the docker-compose.yml file in your current directory. 

  Usage:

    docker-compose-hosts machine-name
    docker-compose-hosts (will use your default machine name)

NOTE: You must modify your /etc/hosts file FIRST before this script will work.
The script works by appending your docker-machine-ip to your hosts file within particular comment blocks that must first be placed in your /etc/hosts file. You can either do this manually (blocks are below) or run the `docker-compose-hosts-init` command once.

  Usage:
    docker-compose-hosts-init

Contents of /etc/hosts after script:

```
# Previous contents
### BEGIN DOCKER COMPOSE HOST LIST ###
### END DOCKER COMPOST HOST LIST ###

```

#### docker-login

- Will log you into bnproducts ECR registry. Note that this requires that you have the aws-cli installed and configured for bnproducts account.

## Docker Igor

The docker-igor script will decompose your current docker-compose.yml file into two separate files; `docker-compose-stravinsky.yml` and `docker-compose-igor.yml` The "igor" file will contain the image specified in the command, and any necessary dependencies from the docker-compose.yml file, and the "stravinsky" file will contain everything else. The intention of this script is to easily allow you to maintain databases, services, etc. that are necessary for your infrastructure outside of your ordinary builds.

  Usage:
    ./docker-igor api create

The available commands are as follows:

1. create - Just creates the two files so that they can be run separately.
2. up - Runs the "docker-compose up" command on the "igor" file (to be used if your stravinsky file is already "up")
3. up_all - Runs the "docker-compose up" command on each of the "igor" file and "stravinsky" files and outputs their asynchronous output. (Also waits 5 seconds between to allow any linked containers from stravinsky to come up first.)
4. build - Runs the "docker-compose build" command on the "igor" file.
5. build_all - Runs the "docker-compose build" command on each of "igor" and "stravinsky" files.

   Typical usage will be:
   1. Create docker-igor files `docker-igor <image> create`
   2. Run docker-compose up on persistent files `docker-compose -f docker-compose-stravinsky up`
   3. Run docker-compose up on local changing files (potentially rebuilding) `docker-igor <image> up` and/or `docker-igor <image> build`

## Parse Args

- Will parse a clear.yml file from the cluster-builder project. (inventory/{account}/group_vars/all/clear.yml)

Usage:

```
parse_args {filename} {property.name.one} [{property.name} ... |] [service_name .. |]
```
