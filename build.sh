#!/bin/bash

DOCKER_REGISTRY_USERNAME="$1"
DOCKER_REGISTRY_PASSWORD="$2"

# Default compose args
COMPOSE_ARGS=" -f build.yml -p identidock "

# Make sure old containers are gone
sudo docker-compose $COMPOSE_ARGS stop
sudo docker-compose $COMPOSE_ARGS rm --force -v

# build the system
sudo docker-compose $COMPOSE_ARGS build --no-cache
sudo docker-compose $COMPOSE_ARGS up -d

# Run unit tests
sudo docker-compose $COMPOSE_ARGS run --no-deps --rm -e ENV=UNIT identidock
ERR=$?

# Run system test if unit tests passed
if [ $ERR -eq 0 ]; then
  IP=$(sudo docker inspect -f {{.NetworkSettings.IPAddress}} \
          identidock_identidock_1)
  CODE=$(curl -sL -w "%{http_code}" $IP:9090/monster/bla -o /dev/null) || true
  if [ $CODE -ne 200 ]; then
    echo "Site returned " $CODE
    ERR=1
  else
    echo 'Test passed - Tagging'
    HASH=$(git rev-parse --short HEAD)
    sudo docker tag -f buildbot_identidock pandurao/identidock:$HASH
    sudo docker tag -f buildbot_identidock pandurao/identidock:newest
    echo 'Pushing'
    sudo docker login -u "$DOCKER_REGISTRY_USERNAME" -p "$DOCKER_REGISTRY_PASSWORD"
    sudo docker push pandurao/identidock:$HASH
    sudo docker push pandurao/identidock:newest
  fi
fi

# Pull down the system
sudo docker-compose $COMPOSE_ARGS stop
sudo docker-compose $COMPOSE_ARGS rm --force -v

echo $ERR
