#!/bin/bash

display_help() {
    echo "Usage: $0 {build|start|down}" >&2
    echo
    exit 1
}

init() {
  CURRENT_DIR=$(pwd)
  DD_REPO="https://github.com/DefectDojo/django-DefectDojo"
  DD_FOLDER="$(pwd)/$(echo $DD_REPO|rev|cut -d"/" -f 1|rev)"
  # Show settings
  echo -e "\033[0;32mSettings\033[0m"
  echo "CURRENT_DIR: $CURRENT_DIR"
  echo "DD_REPO: $DD_REPO"
  echo "DD_FOLDER: $DD_FOLDER"
}

# Build DefectDojo docker images (=~ 4min) : defectdojo-nginx, defectdojo-django
build() {
  # Clone DefectDojo project
  if [ ! -d "$DD_FOLDER" ]; then
    git clone $DD_REPO
  fi
  cd "$DD_FOLDER" && source ./dc-build.sh && cd "$CURRENT_DIR" || exit
}

# Starting docker compose with the profile postgres-redis
start() {
  PROFILE="postgres-redis"
  # show default environment variables
  echo -e "\033[0;32mDefault environment variables\033[0m"
  grep -v "DD_DATABASE_PASSWORD" "$DD_FOLDER/docker/environments/$PROFILE.env"|grep -ve '^$'
  # the initializer can take up to 3 minutes to run, use docker-compose logs -f initializer to track progress
  cd "$DD_FOLDER" && source ./dc-up-d.sh $PROFILE && cd "$CURRENT_DIR" || exit
  # obtain admin credentials
  admin_password=$(grep "DD_DATABASE_PASSWORD" "$DD_FOLDER/docker/environments/$PROFILE.env"|cut -d"=" -f2-)
  echo -e "\033[0;32madmin_password:\033[0m $admin_password"
}

# Remove DefectDojo containers/volumes
down() {
  cd "$DD_FOLDER" && ./dc-down.sh
  # shellcheck disable=SC2046
  docker volume rm $(docker volume ls --filter name=django-defectdojo) &> /dev/null
}

case "$1" in
  build)
    init
    build
    ;;
  start)
    init
    build
    start
    ;;
  down)
    init
    down
    ;;
  *)
     display_help
     exit 1
     ;;
esac
