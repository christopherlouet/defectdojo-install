#!/bin/bash

display_help() {
    echo "Usage: $0 {build|start|down|env|credentials}" >&2
    echo
    exit 1
}

# show environment variables
show_env() {
  echo -e "\033[0;32mEnvironment variables\033[0m"
  grep -v "DD_DATABASE_PASSWORD" "$DD_FOLDER/docker/environments/$PROFILE.env"|grep -ve '^$'
}

# obtain admin credentials
show_credentials() {
  admin_password=$(docker-compose --log-level ERROR -f $DD_FOLDER/docker-compose.yml logs initializer\
    |grep "Admin password:"|awk '{ print $5 }')
  echo -e "\033[0;32madmin_user:\033[0m admin"
  echo -e "\033[0;32madmin_password:\033[0m $admin_password"
}

# Build DefectDojo docker images (=~ 4min) : defectdojo-nginx, defectdojo-django
build() {
  # Clone DefectDojo project
  if [ ! -d "$DD_FOLDER" ]; then
    git clone "$DD_REPO"
  fi
  cd "$DD_FOLDER" && source ./dc-build.sh && cd "$CURRENT_DIR" || exit
}

# Starting docker compose with the profile postgres-redis
start() {
  show_env
  # the initializer can take up to 3 minutes to run, use docker-compose logs -f initializer to track progress
  cd "$DD_FOLDER" && source ./dc-up-d.sh "$PROFILE" && cd "$CURRENT_DIR" || exit
  show_credentials
}

# Remove DefectDojo containers/volumes
down() {
  cd "$DD_FOLDER" && ./dc-down.sh
  # shellcheck disable=SC2046
  docker volume rm $(docker volume ls --filter name=django-defectdojo) &> /dev/null
}

CURRENT_DIR=$(pwd)
DD_REPO="https://github.com/DefectDojo/django-DefectDojo"
DD_FOLDER="$(pwd)/$(echo $DD_REPO|rev|cut -d"/" -f 1|rev)"
PROFILE="postgres-redis"
DEBUG=0

# Show settings
if [ $DEBUG -eq 1 ]; then
  echo -e "\033[0;32mCurrent settings\033[0m"
  echo "CURRENT_DIR: $CURRENT_DIR"
  echo "DD_REPO: $DD_REPO"
  echo "DD_FOLDER: $DD_FOLDER"
  echo "PROFILE: $PROFILE"
fi

case "$1" in
  build)
    build
    ;;
  start)
    build
    start
    ;;
  down)
    down
    ;;
  env)
    show_env
    ;;
  credentials)
    show_credentials
    ;;
  *)
     display_help
     exit 1
     ;;
esac
