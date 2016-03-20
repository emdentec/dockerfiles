#!/bin/bash
set -e

if [[ -n ${DOCKER_GROUP_ID} ]]; then
    # groupadd -g ${DOCKER_GROUP_ID} docker
    sudo usermod -a -G ${DOCKER_GROUP_ID} jenkins
fi

exec "$@"