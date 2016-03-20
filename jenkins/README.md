# Jenkins Docker Image

This is a container that inherits from the [official Jenkins LTS docker image](https://hub.docker.com/_/jenkins/). It has the capability to pass a docker socket & binary as volumes, and use the host's docker installation inside jenkins build jobs.

## Usage

```bash
docker run -dp 8080:8080 -p 50000:50000 \
    -e DOCKER_GROUP_ID=$(getent group docker | cut -d: -f3) \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $(which docker):/usr/bin/docker \
    emdentec/jenkins
```