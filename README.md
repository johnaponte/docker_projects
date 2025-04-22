# RStudio Docker Environment

To create reproducible R development environments

*create_docker_projects.sh*
This script setup configures a Docker image with RStudio Server accessible via an `ngrok` tunnel.

## Project Structure

- `docker/`: Files to build and manage the container.
- `docker/Dockerfile`: Defines the R environment with RStudio.
- `docker/secrets/`: Directory for storing sensitive data
- `projects/`: Folder where RStudio projects will be mounted.

## Instructions

### 1. Update docker/secrets/secrets.env

Change to the docker directory and update secrets/secrets.env with a
text editor. Be carefull not to include espaces around the "="
Us a plain text editor as nano, vs_code or similar. Never use a word 
processor like Microsoft(R) word.

| PARAMETERS        | DESCRIPTION                                       |
|-------------------|---------------------------------------------------|
| R_VERSION         | Version of R to be used                           |
| RSTUDIO_USER      | Username for RStudio Server                       |
| RSTUDIO_PASSWORD  | Password for RStudio Server                       |
| NGROK_AUTHTOKEN   | Auth token for Ngrok tunnel                       |
| NGROK_DOMAIN      | Custom domain used with Ngrok to access externaly |
| IMAGE_NAME        | Name of the Docker image                          |
| IMAGE_TAG         | Tag/version of the Docker image                   |
| CONTAINER_ID      | ID of the running Docker container                |
| CONTAINER_PORT    | Port exposed by the container to access internaly |

The internal port of the rstudio in the container is 8787 but to allow several 
containers to run, you can change it to another port so the container can be
accessed using http://localhost:CONTAINER_PORT
The IMAGE_NAME and IMAGE_TAG will be use to identify the image but the
CONTAINER_ID when running in docker

To access the container from the exterior the ngrok domain should be
setup, and a DNS service (ej Infomaniak) should have an entry where the CNAME is
directed to the corresponding value in ngrok. by default the  ngrok
tunnel is SSL but check before sensitive information is transmitted like
passwords. If no NGROK variables are provided you need other means
to expose the container to the exterior.


### 2 Manage the container

In the docker directory you can manage the container with the following command

```bash
./container build
./continer run
./container stop
./container restart
./container delete
```

### 3. Use the container
The home of the default user is map to the `projects` directory
in the host. You can use the container as a normal rstudio container

By default, the container uses the `RStudio` available at the last date of the `R_VERSION`
and sets the package manager to `Posit Package Manager` to the date of the `R_VERSION`
The container has installed `pkgr` and together with the `env`  you
can achive an extra layer of confidence for the reproduciblity of the analysis
The recomendation is for each new project setup a pkgr.yml file and use `env``
as library.

For the `R_VERSION`and `RStudio` follow 
[rocker-versioned2 versions and dates](https://github.com/rocker-org/rocker-versioned2/wiki/Versions)

Follow [pkgr documentation](https://metrumresearchgroup.github.io/pkgr/docs/) for more information
on how to setup pkgr in your projects
