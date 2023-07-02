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
_profile_check() {
  _show_message "Check current profile..."
#  todo, to check the profile.env file...
}

# Edit the current profile
_profile_edit() {
  _show_message "Edit profile..."

}

# Create a token api
_auth_create_token() {
  docker-compose --log-level ERROR -f "$DD_FOLDER/docker-compose.yml" exec celerybeat bash -c "/app/manage.py changepassword"
  #  docker-compose --log-level ERROR -f "$DD_FOLDER/docker-compose.yml" exec celerybeat bash -c "/app/manage.py drf_create_token"
#  docker-compose --log-level ERROR -f "$DD_FOLDER/docker-compose.yml" exec celerybeat bash -c "/app/manage.py dumpdata --skip-checks auth.user"
}

# Get the current token api
_auth_get_token() {
  command="/app/manage.py dumpdata --skip-checks authtoken.token"
  token=$(docker-compose --log-level ERROR -f "$DD_FOLDER/docker-compose.yml" exec celerybeat bash -c "$command"|jq -r '.[0].pk')
  echo "TOKEN: $token"
}

# Create a profile with the default file
_profile_create() {
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
      _show_message "The folder $PROFILE_DEFAULT_FOLDER does not contain any profile files!" 1
      exit 1
    fi
    # Choice the profile
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

# Check app status
_app_status() {
  docker-compose --log-level ERROR -f "$DD_FOLDER/docker-compose.yml" ps -q celerybeat&>/dev/null
  # shellcheck disable=SC2181
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

# Display help :)
display_help() {
  if [ "$1" = "show" ]; then
     _show_message "Usage: $0 show {status|release|env|credentials|token|logs}" >&2
  elif [ "$1" = "stop" ]; then
    _show_message "Usage: $0 stop [--remove]" >&2
  else
    _show_message "Usage: $0 {start|stop|init|show}" >&2
  fi
  echo
  exit 1
}

# Initialize the project
project_init() {
  new_profile=0
  if [ ! -f "$PROFILE_FILE" ] || [ ! -d "$DD_FOLDER" ]; then
    # Clone DefectDojo project if the folder not exist
    if [ ! -d "$DD_FOLDER" ]; then
      _show_message "Clone the DefectDojo project"
      release=$(curl -s "$DD_REPO_API/releases/latest"|jq -r .tag_name)
      message_clone_latest=$(_show_confirm_message "Clone the latest version of DefectDojo ($release)? [Y/n] " "y")
      if [ -z "$message_clone_latest" ]; then
        release=""
        while [ -z "$release" ]; do
          read -r -p "Enter release version: " response_release
          release=$(curl  -s "$DD_REPO_API/tags"|jq -r ".[]|select( .name == \"$response_release\" ).name")
          if [ -z "$release" ]; then
            _show_message "$response_release is not a valid version!" 1
          fi
        done
      fi
      git clone --depth 1 --branch "$release" "$DD_REPO"
    fi
    message="Currently, no profile is configured. Do you want to use choose one? [Y/n] "
    choice_profile=$(_show_confirm_message "$message" "y")
    if [ -n "$choice_profile" ]; then
      _profile_create && new_profile=1
    else
      _show_message "Please configure a profile before starting the application!" 1
      exit 1
    fi
  fi
  PROFILE=$(grep "DD_PROFILE" "$PROFILE_FILE"|cut -d'=' -f2)
  release=$(cd "$DD_FOLDER" && git describe)
  if [ $new_profile -eq 1 ]; then
    _show_message "The project is now configured with the $PROFILE profile and the release $release"
  fi
}

show() {
  # show application status
  if [ "$1" = "status" ]; then
    app_status=$(_app_status)
    if [ "$app_status" = "up" ]; then
      _show_message "Application is started."
    elif [ "$app_status" = "stop" ]; then
      _show_message "Application is stopped."
    else
      _show_message "Application was never launched..."
    fi
  fi
  # show current release
  if [ "$1" = "release" ]; then
    if [ ! -d "$DD_FOLDER" ]; then
      _show_message "Project DefectDojo not exist, have you already started the application?" 1
    else
      release=$(cd "$DD_FOLDER" && git describe)
      _show_message "Current release: $release"
    fi
  fi
  # show environment variables
  if [ "$1" = "env" ]; then
    project_init
    _show_message "Environment variables"
    grep -v "DD_DATABASE_PASSWORD" "profile.env"|grep -ve '^$'
  fi
  # show credentials
  if [ "$1" = "credentials" ]; then
    _show_message "Obtaining credentials..."
    admin_password=$(docker-compose --log-level ERROR -f "$DD_FOLDER/docker-compose.yml" logs initializer\
      |grep "Admin password:"|grep -v "Initialization"|awk '{ print $5 }')
    if [ -z "$admin_password" ]; then
      _show_message "No credentials... Have you started the application yet? (./ddadmin.sh start)"
    else
      echo -e "\033[0;32madmin_user:\033[0m admin"
      echo -e "\033[0;32madmin_password:\033[0m $admin_password"
    fi
  fi
#  # show api token...
#
  # Shown container logs
  if [ "$1" = "logs" ]; then
    app_status=$(_app_status)
    if [ ! "$app_status" = "up" ]; then
      _show_message "Application is not started!"
    else
      docker-compose --log-level ERROR -f "$DD_FOLDER/docker-compose.yml" logs -f celerybeat
    fi
  fi
}

# Starting docker compose with the profile postgres-redis
start() {
  project_init
  app_status=$(_app_status)
  if [ "$app_status" = "up" ]; then
    _show_message "Application is already started!"
  else
    if [ "$app_status" = "down" ]; then
      # Build DefectDojo docker images (=~ 4min) : defectdojo-nginx, defectdojo-django
      _show_message "Image building..."
      cd "$DD_FOLDER" && source ./dc-build.sh >&/dev/null && cd "$CURRENT_DIR" || exit
    fi
    _show_message "Starting application..."
    docker-compose -f "$DD_FOLDER/docker-compose.yml" --profile "$PROFILE" --env-file "profile.env" up --no-deps -d
    _waiting_start
    _show_message "Done! To display the credentials, issue the command: ./ddadmin.sh show credentials"
  fi
}

# Stop/remove DefectDojo containers
stop() {
  option=$1
  project_init
  # Remove DefectDojo containers/volumes
  if [[ -n $option ]] && [ "$option" = "--remove" ]; then
    are_you_sure=$(_show_confirm_message "Are you sure? [y/N] ")
    if [ -n "$are_you_sure" ]; then
      _show_message "Remove application containers..."
      docker-compose -f "$DD_FOLDER/docker-compose.yml" --profile "$PROFILE" --env-file "profile.env" down
      # shellcheck disable=SC2046
      docker volume rm $(docker volume ls --filter name=django-defectdojo) &>/dev/null
      _show_message "Done!"
    fi
  fi
  # Stop the application
  if [ -z "$option" ]; then
    app_status=$(_app_status)
    if [ ! "$app_status" = "up" ]; then
      _show_message "Application is already stopped!"
    else
      _show_message "Stopping application containers..."
      docker-compose -f "$DD_FOLDER/docker-compose.yml" --profile "$PROFILE" --env-file "profile.env" stop
      _show_message "Done!"
    fi
  fi
}

# Script variables
CURRENT_DIR=$(pwd)
DD_REPO="https://github.com/DefectDojo/django-DefectDojo"
DD_REPO_API="https://api.github.com/repos/DefectDojo/django-DefectDojo"
DD_FOLDER="$(pwd)/$(echo $DD_REPO|rev|cut -d"/" -f1|rev)"
PROFILE_FILE="profile.env"
PROFILE_DEFAULT_FOLDER="$DD_FOLDER/docker/environments"
PROFILE_DEFAULT="postgres-redis"

## Menu
options=$#
if [ $options -eq 0 ]; then
  display_help
else
  case "$1" in
    start)
      if [ ! $options -eq 1 ]; then display_help; fi
      start
      ;;
    stop)
      option=$2
      if [ $options -eq 2 ]; then
        if [ ! "$option" = "--remove" ]; then display_help stop; fi
      elif [ ! $options -eq 1 ]; then
        display_help stop
      fi
      stop "$option"
      ;;
    show)
      if [ ! $options -eq 2 ]; then
        display_help show
      else
        if [[ ! $2 =~ status|release|env|credentials|token|logs ]]; then display_help show; fi
        show "$2"
      fi
      ;;
    init)
      project_init
      ;;
    *)
      display_help
      ;;
  esac
fi
