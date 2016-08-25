#!/bin/bash

DOCKER_REGISTRY_USERNAME="$1";
DOCKER_REGISTRY_PASSWORD="$2";

DOCKER_PREFIX="$DOCKER_REGISTRY_USERNAME";
PROJECT='identidock';

# Default compose args
COMPOSE_ARGS=" -f build.yml -p $PROJECT ";

# Make sure old containers are gone
sudo docker-compose $COMPOSE_ARGS stop;
sudo docker-compose $COMPOSE_ARGS rm --force -v;

# Build the system
sudo docker-compose $COMPOSE_ARGS build --no-cache;
sudo docker-compose $COMPOSE_ARGS up -d;

# Run unit tests
sudo docker-compose $COMPOSE_ARGS run --no-deps --rm -e ENV=UNIT "$PROJECT";
ERR="$?";

# Run system test if unit tests passed
if [ $ERR -eq 0 ]; then
    IP=$(sudo docker inspect -f {{.NetworkSettings.IPAddress}} "${PROJECT}_${PROJECT}_1");
    CODE=$(curl -sL -w "%{http_code}" "$IP:9090/monster/bla" -o /dev/null) || true;
    if [ "$CODE" -ne 200 ]; then
        echo "Site returned " "$CODE";
        ERR=1;
    else
        # Tag and push images to registry
        echo 'Test passed - tagging image';
        HASH=$(git rev-parse --short HEAD);
        sudo docker tag "$PROJECT" "$DOCKER_PREFIX/$PROJECT:$HASH";
        sudo docker tag "$PROJECT" "$DOCKER_PREFIX/$PROJECT:newest";

        echo 'Pushing image';
        sudo docker login -u "$DOCKER_REGISTRY_USERNAME" -p "$DOCKER_REGISTRY_PASSWORD";
        sudo docker push "$DOCKER_PREFIX/$PROJECT:$HASH";
        sudo docker push "$DOCKER_PREFIX/$PROJECT:newest";
    fi
fi

# Pull down the system
sudo docker-compose $COMPOSE_ARGS stop;
sudo docker-compose $COMPOSE_ARGS rm --force -v;

echo "$ERR";
