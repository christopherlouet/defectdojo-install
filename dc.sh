#!/bin/bash

# Show confirmation message...
_show_confirm_message() {
  read -r -p "Are you sure? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY])
      echo "y"
      ;;
    *)
      echo ""
      ;;
  esac
}

# Show message...
_show_message() {
  echo -e "\033[0;32m$1\033[0m"
}

# Build DefectDojo docker images (=~ 4min) : defectdojo-nginx, defectdojo-django
_build() {
  # Clone DefectDojo project
  if [ ! -d "$DD_FOLDER" ]; then
    _show_message "Clone the DefectDojo project"
    git clone "$DD_REPO"
  fi
  _show_message "Image building..."
  cd "$DD_FOLDER" && source ./dc-build.sh >&/dev/null && cd "$CURRENT_DIR" || exit
}

# Check app status
_app_status() {
  docker-compose --log-level ERROR -f "$DD_FOLDER/docker-compose.yml" ps -q celerybeat&>/dev/null
  if [ ! $? -eq 0 ]; then
      echo "down"
  else
    # shellcheck disable=SC2046
    app_status=$(docker ps -q --no-trunc|\
            grep $(docker-compose --log-level ERROR -f "$DD_FOLDER/docker-compose.yml" ps -q celerybeat))
    if [ -z "$app_status" ]; then
      echo "stop"
    else
      echo "up"
    fi
  fi
}

# Check initializer status
_initializer_status() {
  # shellcheck disable=SC2046
  initializer_status=$(docker ps -q --no-trunc | \
          grep $(docker-compose --log-level ERROR -f "$DD_FOLDER/docker-compose.yml" ps -q initializer))
  if [ -z "$initializer_status" ]; then
    echo "stop"
  else
    echo "up"
  fi
}

# Waiting application start
_waiting_start() {
  i=0
  spin='-\|/'
  start=$(date +%s)
  initializer_status="up"
  while [ "$initializer_status" = "up" ]; do
    i=$(( (i+1) %4 ))
    printf "\r\033[0;32mWaiting application start... ${spin:$i:1}"
    sleep 0.2
    initializer_status=$(_initializer_status)
  done
  cur=$(date +%s)
  runtime=$(( cur-start ))
  printf " done (%ss)\033[0m\n" $runtime
}

# Display help :)
display_help() {
    _show_message "Usage: $0 {start|down|stop|env|status|credentials|log}" >&2
    echo
    exit 1
}

# show environment variables
show_env() {
  _show_message "Environment variables"
  grep -v "DD_DATABASE_PASSWORD" "$DD_FOLDER/docker/environments/$PROFILE.env"|grep -ve '^$'
}

# obtain admin credentials
show_credentials() {
  _show_message "Obtaining credentials..."
  admin_password=$(docker-compose --log-level ERROR -f "$DD_FOLDER/docker-compose.yml" logs initializer\
    |grep "Admin password:"|grep -v "Initialization"|awk '{ print $5 }')
  if [ -z "$admin_password" ]; then
    _show_message "No credentials... Have you started the application yet? (./dc.sh start)"
  else
    echo -e "\033[0;32madmin_user:\033[0m admin"
    echo -e "\033[0;32madmin_password:\033[0m $admin_password"
  fi
}

# Get application status
status() {
  app_status=$(_app_status)
  if [ "$app_status" = "up" ]; then
    _show_message "Application is started."
  elif [ "$app_status" = "stop" ]; then
    _show_message "Application is stopped."
  else
    _show_message "Application was never launched..."
  fi
}

# Starting docker compose with the profile postgres-redis
start() {
  app_status=$(_app_status)
  if [ "$app_status" = "up" ]; then
    _show_message "Application is already started!"
  else
    if [ "$app_status" = "down" ]; then
      _build
    fi
    _show_message "Starting application..."
    cd "$DD_FOLDER" && ./dc-up-d.sh "$PROFILE" >&/dev/null
    _waiting_start
    _show_message "Done! To display the credentials, issue the command: ./dc.sh credentials"
  fi
}

# Stop DefectDojo containers
stop() {
  app_status=$(_app_status)
  if [ ! "$app_status" = "up" ]; then
    _show_message "Application is already stopped!"
  else
    _show_message "Stopping application containers..."
    cd "$DD_FOLDER" && ./dc-stop.sh >&/dev/null
    _show_message "Done!"
  fi
}

# Remove DefectDojo containers/volumes
down() {
  are_you_sure=$(_show_confirm_message)
  if [ -n "$are_you_sure" ]; then
    _show_message "Remove application containers..."
    cd "$DD_FOLDER" && ./dc-down.sh &>/dev/null
    # shellcheck disable=SC2046
    docker volume rm $(docker volume ls --filter name=django-defectdojo) &>/dev/null
    _show_message "Done!"
  fi
}

# Show celerybeat container logs
show_log() {
  app_status=$(_app_status)
  if [ ! "$app_status" = "up" ]; then
    _show_message "Application is not started!"
  else
    docker-compose --log-level ERROR -f "$DD_FOLDER/docker-compose.yml" logs -f celerybeat
  fi
}

# Script variables
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

# Menu
case "$1" in
  status)
    status
    ;;
  start)
    start
    ;;
  down)
    down
    ;;
  stop)
    stop
    ;;
  env)
    show_env
    ;;
  credentials)
    show_credentials
    ;;
  log)
    show_log
    ;;
  *)
     display_help
     exit 1
     ;;
esac
