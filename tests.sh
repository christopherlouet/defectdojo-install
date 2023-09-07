#!/usr/bin/env bash

DOCKER_IMAGE=defectdojo_install:1.0.0

if [[ "$(docker images -q $DOCKER_IMAGE 2> /dev/null)" == "" ]]; then
  DOCKER_BUILDKIT=1 docker build --target=runtime -t=$DOCKER_IMAGE .
fi

#docker run --rm -it \
#    $DOCKER_IMAGE pytest tests/

docker run --rm -it \
  -v "$(pwd)/libs:/app/libs" \
  -v "$(pwd)/tests:/app/tests" \
  $DOCKER_IMAGE pytest tests/

#docker run --rm -it \
#  -v "$(pwd)/libs:/app/libs" \
#  -v "$(pwd)/tests:/app/tests" \
#  $DOCKER_IMAGE bash
