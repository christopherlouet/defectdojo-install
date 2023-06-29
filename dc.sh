#!/bin/bash

# Show confirmation message...
_show_confirm_message() {
  default_answer=$2
  read -r -p "$1" response
  if [ -z "$response" ]; then
    echo "$default_answer"
    exit
  fi
  case "$response" in [yY][eE][sS]|[yY])
      echo "y"
      ;;
    *)
      echo ""
      ;;
  esac
}

# Show message...
_show_message() {
  msg=$1
  level=$2
  msg_start="\033[0;32m"
  msg_end="\033[0m"
  # level>0 => error message
  if [ -n "$level" ] && [ "$level" -gt 0 ]; then
    msg_start="\033[0;31m"
  fi
  # level<0 => info message
  if [ -n "$level" ] && [ "$level" -lt 0 ]; then
    msg_start="\033[0m"
  fi
  echo -e "$msg_start$msg$msg_end"
}

# Check the current profile
_profile_default_check() {
  _show_message "Check current profile..."
#  todo, to check the profile.env file...
}

# Create a new profile
_profile_create() {
  _show_message "create new profile..."
#  todo, to set password, etc...
}

# Create a profile with the default file
_profile_default_create() {
  if [ -d "$PROFILE_DEFAULT_FOLDER" ]; then
    choice=0
    choice_default=0
    # List the default profiles
    _show_message "List of available profiles:"
    message=""
    for profile_default_file_path in "$PROFILE_DEFAULT_FOLDER"/*; do
      choice=$(( choice+1 ))
      profile_default_file="$(echo "$profile_default_file_path"|rev|cut -d"/" -f1|cut -d"." -f2-|rev)"
      if [ $choice -eq 1 ]; then
        message="$profile_default_file [$choice]"
      else
        message="$message\n$profile_default_file [$choice]"
      fi
      if [ "$PROFILE_DEFAULT" = "$profile_default_file" ]; then
        choice_default=$choice
        message="$message *"
      fi
    done
    # Empty folder...
    if [ $choice -eq 0 ]; then
      message_confirm="The folder $PROFILE_DEFAULT_FOLDER does not contain any profile files!Do you want generate a new one? [Y/n] "
      create_default_profile=$(_show_confirm_message "$message_confirm" "y")
      if [ -n "$create_default_profile" ]; then
        _profile_create
      else
        _show_message "Please configure a profile before starting the application!" 1
        exit 1
      fi

    fi
    # Choice the default profile
    response=0
    while [ $response -lt 1 ] || [ $response -gt $choice ]; do
      _show_message "$message" -1
      confirm_message="\e[32mChoice a default profile (default $choice_default) [1-$choice] \e[0m"
      echo -ne "\e[32m$confirm_message\e[0m"; read -r -e -p "${confirm_message//?/$'\a'}" response
      if [ -z "$response" ]; then
        response=$choice_default
      fi
      if ! [[ $response =~ ^[0-9]+$ ]] ; then
        response=0
      fi
    done
    # Get the default profile path
    choice_profile=0
    profile_default_file_path_target=""
    for profile_default_file_path in "$PROFILE_DEFAULT_FOLDER"/*; do
      choice_profile=$(( choice_profile+1 ))
      if [ $choice_profile -eq $response ]; then
        profile_default_file_path_target=$profile_default_file_path
        profile_default_file_target="$(echo "$profile_default_file_path_target"|rev|cut -d"/" -f1|cut -d"." -f2-|rev)"
      fi
    done
    # Copy default profile in the project folder
    _show_message "create default profile..."
    cp "$profile_default_file_path_target" "$PROFILE_FILE"
    # Tag the profile in the file
    echo "DD_PROFILE=$profile_default_file_target">>"$PROFILE_FILE"
  # Folder not exist...
  else
    _show_message "Folder $PROFILE_DEFAULT_FOLDER not exist!" 1
    exit 1
  fi
}

# Build DefectDojo docker images (=~ 4min) : defectdojo-nginx, defectdojo-django
_build() {
  # Clone DefectDojo project if the folder not exist
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
    printf "\r\033[0;32mWaiting application start... %s" ${spin:$i:1}
    sleep 0.2
    initializer_status=$(_initializer_status)
  done
  cur=$(date +%s)
  runtime=$(( cur-start ))
  printf " done (%ss)\033[0m\n" $runtime
}

# starting app with docker-compose and the project profile
_docker_compose_start() {
  docker-compose -f "$DD_FOLDER/docker-compose.yml" --profile "$PROFILE" --env-file "$PROFILE.env" up --no-deps -d
}

# Display help :)
display_help() {
  _show_message "Usage: $0 {start|down|stop|init|env|status|credentials|log}" >&2
  echo
  exit 1
}

# Initialize the profile
profile_init() {
  if [ ! -f "$PROFILE_FILE" ]; then
    message="Currently, no profile is configured. Do you want to use the default one? [Y/n] "
    use_default_profile=$(_show_confirm_message "$message" "y")
    if [ -n "$use_default_profile" ]; then
      _profile_default_create
    else
      create_new_profile=$(_show_confirm_message "Create a new profile? [Y/n] " "y")
      if [ -n "$create_new_profile" ]; then
        _profile_create
      else
        _show_message "Please configure a profile before starting the application!" 1
        exit 1
      fi
    fi
  else
    profile_tag=$(grep "DD_PROFILE" "$PROFILE_FILE"|cut -d'=' -f2)
    _show_message "The project is configured with the $profile_tag profile"
  fi
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

# Show celerybeat container logs
show_log() {
  app_status=$(_app_status)
  if [ ! "$app_status" = "up" ]; then
    _show_message "Application is not started!"
  else
    docker-compose --log-level ERROR -f "$DD_FOLDER/docker-compose.yml" logs -f celerybeat
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
    PROFILE=postgres-redis
    cd "$DD_FOLDER" && ./dc-up-d.sh "$PROFILE" >&/dev/null
    # todo
#    _docker_compose_start
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
  are_you_sure=$(_show_confirm_message "Are you sure? [y/N] ")
  if [ -n "$are_you_sure" ]; then
    _show_message "Remove application containers..."
    cd "$DD_FOLDER" && ./dc-down.sh &>/dev/null
    # shellcheck disable=SC2046
    docker volume rm $(docker volume ls --filter name=django-defectdojo) &>/dev/null
    _show_message "Done!"
  fi
}

# Script variables
CURRENT_DIR=$(pwd)
DD_REPO="https://github.com/DefectDojo/django-DefectDojo"
DD_FOLDER="$(pwd)/$(echo $DD_REPO|rev|cut -d"/" -f1|rev)"
PROFILE_FILE="profile.env"
PROFILE_DEFAULT_FOLDER="$DD_FOLDER/docker/environments"
PROFILE_DEFAULT="postgres-redis"
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
  init)
    profile_init
    ;;
  start)
    profile_init
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
