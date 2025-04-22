#!/bin/bash

# Should be run in the directory of the new project

mkdir -p "docker"
mkdir -p "projects"
mkdir -p "docker/secrets"
cat << 'EOF' > "docker/Dockerfile"
# syntax=docker/dockerfile:1.4
ARG R_VERSION
FROM rocker/verse:${R_VERSION}

RUN apt-get update && apt-get install -y curl unzip gnupg && \
    curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null && \
    echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | tee /etc/apt/sources.list.d/ngrok.list && \
    apt-get update && apt-get install -y ngrok

RUN --mount=type=secret,id=r_secrets \
    . /run/secrets/r_secrets && \
    useradd -m "$RSTUDIO_USER" && \
    echo "$RSTUDIO_USER:$RSTUDIO_PASSWORD" | chpasswd && \
    adduser "$RSTUDIO_USER" sudo 

COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8787 4040 

CMD ["/entrypoint.sh"]

EOF

cat << 'CEOF' > "docker/container"
#!/bin/bash

set -e

# Path to the secrets file
SECRETS_FILE="secrets/secret.env"

# Load the variables
if [ -f "$SECRETS_FILE" ]; then
  source $SECRETS_FILE
else
  echo "Secrets file not found: $SECRETS_FILE"
  exit 1
fi

case "$1" in
  build)
    echo "Building image $IMAGE_NAME:$IMAGE_TAG..."
    export DOCKER_BUILDKIT=1
    docker build \
      --build-arg R_VERSION=$R_VERSION \
      --secret id=r_secrets,src=$SECRETS_FILE \
      -t $IMAGE_NAME:$IMAGE_TAG \
      .
    echo "Image $IMAGE_NAME:$IMAGE_TAG built successfully."
    ;;

  run)
    echo "Running container $CONTAINER_ID..."

    cat > secrets/ngrok.yml <<EOF
version: 2
authtoken: ${NGROK_AUTHTOKEN}
log: /var/log/ngrok.log

tunnels:
  default:
    proto: http
    addr: 8787
    domain: ${NGROK_DOMAIN}
EOF

    docker run -d \
      --name $CONTAINER_ID \
      -p $CONTAINER_PORT:8787 \
      -v $(pwd)/../projects:/home/$RSTUDIO_USER:rw \
      -v $(pwd)/secrets/ngrok.yml:/root/.config/ngrok/ngrok.yml \
      $IMAGE_NAME:$IMAGE_TAG

    echo "$IMAGE_NAME:$IMAGE_TAG is running as $CONTAINER_ID" 
    echo "Local: http://localhost:$CONTAINER_PORT"
    echo "Remote: https://$NGROK_DOMAIN"
    ;;

  stop)
    echo "Stopping container $CONTAINER_ID..."
    docker stop $CONTAINER_ID
    echo "$CONTAINER_ID stopped."
    ;;

  restart)
    echo "Restarting container $CONTAINER_ID..."
    docker restart $CONTAINER_ID
    echo "$CONTAINER_ID restarted at http://localhost:$CONTAINER_PORT"
    ;;

  delete)
    echo "Deleting container and image..."
    docker rm -f $CONTAINER_ID || true
    docker rmi $IMAGE_NAME:$IMAGE_TAG
    echo "Container and image deleted."
    ;;

  *)
    echo "Usage: $0 {build|run|stop|restart|delete}"
    exit 1
    ;;
esac
CEOF
chmod +x docker/container

cat << 'EOF' > "docker/.dockerignore"
# TODO updated together with .gitignore
secrets/
EOF

cat << 'EOF' > "docker/docker-entrypoint.sh"
#!/bin/bash

# Start tunnels 
ngrok start --all  &

# Execute entrypoint of RStudio
/init
EOF

cat << 'EOF' > "docker/secrets/secret.env.example"
# secret.env variables
R_VERSION=4.3.4
RSTUDIO_USER=user_name
RSTUDIO_PASSWORD=verygoodpassword
NGROK_AUTHTOKEN=auth_token
NGROK_DOMAIN=domain.name
IMAGE_NAME=image_name
IMAGE_TAG=latest
CONTAINER_PORT=8787
CONTAINER_ID=container_id
EOF

cat << 'EOF' > "docker/secrets/secret.env"
# secret.env variables
R_VERSION=
RSTUDIO_USER=
RSTUDIO_PASSWORD=
NGROK_AUTHTOKEN=
NGROK_DOMAIN=
CONTAINER_PORT=
IMAGE_NAME=
IMAGE_TAG=
CONTAINER_ID=
EOF


cat << 'EOF' > "docker/README.md"
# RStudio Docker Environment

This setup configures a Docker image with RStudio Server accessible via an `ngrok` tunnel.

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
EOF


echo ".. Project created. "
echo "Update docker/secrets/secrets.env before building the container"