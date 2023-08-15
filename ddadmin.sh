#!/bin/bash

# Show confirmation message...
_show_confirm_message() {
  default_answer=$2
  read -r -p "$1" choice_profile_selected
  if [ -z "$choice_profile_selected" ]; then
    echo "$default_answer"
    exit
  fi
  case "$choice_profile_selected" in [yY][eE][sS]|[yY])
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

# Check app status
_app_status() {
  docker-compose --log-level ERROR -f "$DD_FOLDER/docker-compose.yml" ps -q "$DD_CONTAINER_ADM" &>/dev/null
  # shellcheck disable=SC2181
  if [ ! $? -eq 0 ]; then
      echo "down"
  else
    # shellcheck disable=SC2046
    app_status=$(docker ps -q --no-trunc|\
            grep $(docker-compose --log-level ERROR -f "$DD_FOLDER/docker-compose.yml" ps -q "$DD_CONTAINER_ADM"))
    if [ -z "$app_status" ]; then
      echo "stop"
    else
      echo "up"
    fi
  fi
}

# Get the current token API
_auth_get_token() {
  command="/app/manage.py dumpdata --skip-checks authtoken.token"
  token=$(docker-compose --log-level ERROR -f "$DD_FOLDER/docker-compose.yml" exec celerybeat bash -c "$command"|jq -r '.[0].pk')
  echo -e "\033[0;32mTOKEN:\033[0m $token"
}

# Update the release
_check_release_update() {
  if [ ! "$RELEASE" = "$DD_RELEASE_LATEST" ]; then
    message="A new version of the DefectDojo project has been released: ${DD_RELEASE_LATEST}. Current version is ${RELEASE}. Do you want to update? [y/N] "
    update_project=$(_show_confirm_message "$message")
    if [ -n "$update_project" ]; then
      _project_clone "$DD_RELEASE_LATEST"
      # Update the version
      sed -i -e "/DD_RELEASE=/s/=.*/=$DD_RELEASE_LATEST/" "$PROFILE_FILE"
      # Restart the application
      docker-compose -f "$DD_FOLDER/docker-compose.yml" --profile "$PROFILE" --env-file "profile.env" restart
      _waiting_start
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

# Copy the profile file selected
_profile_copy_selected() {
  choice_profile_selected=$1
  generate_database_password=$2
  # Get the default profile path
  choice_profile=0
  profile_default_file_path_target=""
  for profile_default_file_path in "$PROFILE_DEFAULT_FOLDER"/*; do
    choice_profile=$(( choice_profile+1 ))
    if [ $choice_profile -eq "$choice_profile_selected" ]; then
      profile_default_file_path_target=$profile_default_file_path
      profile_default_file_target="$(echo "$profile_default_file_path_target"|rev|cut -d"/" -f1|cut -d"." -f2-|rev)"
    fi
  done
  # Copy default profile in the project folder
  _show_message "create default profile..."
  cp "$profile_default_file_path_target" "$PROFILE_FILE"
  # Change the default database password
  db_password=""
  # Generate a new database password
  if [[ -n $generate_database_password ]]; then
    db_password=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13 && echo '')
  else
    while [ -z "$db_password" ]; do
      confirm_message="Choice a database password : "
          echo -ne "\e[32m$confirm_message\e[0m"; read -r -e -p "${confirm_message//?/$'\a'}" db_password
    done
  fi
  db_database_url="postgresql\:\/\/defectdojo\:$db_password\@postgres\:5432\/defectdojo"
  sed -i -e "/DD_DATABASE_PASSWORD=/s/=.*/=$db_password/" "$PROFILE_FILE"
  sed -i -e "/DD_DATABASE_URL=/s/=.*/=$db_database_url/" "$PROFILE_FILE"
  # Tag the profile in the profile file
  echo "DD_PROFILE=$profile_default_file_target">>"$PROFILE_FILE"
  # Tag the release in the profile file
  release=$(cd "$DD_FOLDER" && git describe)
  echo "DD_RELEASE=$release">>"$PROFILE_FILE"
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
      if [ "$PROFILE_DEFAULT" = "$choice" ]; then
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
    choice_profile_selected=0
    while [ $choice_profile_selected -lt 1 ] || [ $choice_profile_selected -gt $choice ]; do
      _show_message "$message" -1
      confirm_message="Choice a default profile (default $choice_default) [1-$choice] "
      echo -ne "\e[32m$confirm_message\e[0m"; read -r -e -p "${confirm_message//?/$'\a'}" choice_profile_selected
      if [ -z "$choice_profile_selected" ]; then
        choice_profile_selected=$choice_default
      fi
      if ! [[ $choice_profile_selected =~ ^[0-9]+$ ]] ; then
        choice_profile_selected=0
      fi
    done
    _profile_copy_selected $choice_profile_selected
  # Folder not exist...
  else
    _show_message "Folder $PROFILE_DEFAULT_FOLDER not exist!" 1
    exit 1
  fi
}

# Create a default profile file
_profile_create_default () {
  if [ -d "$PROFILE_DEFAULT_FOLDER" ]; then
    _profile_copy_selected "$PROFILE_DEFAULT" 1
  # Folder not exist...
  else
    _show_message "Folder $PROFILE_DEFAULT_FOLDER not exist!" 1
    exit 1
  fi
}

# Initialize the profile
_profile_init() {
  # Check if the profile file exist
  if [ ! -f "$PROFILE_FILE" ]; then
      message="Currently, no profile is configured."
      exit 1
  fi
  # Set variables for current setting
  PROFILE=$(grep "DD_PROFILE" "$PROFILE_FILE"|cut -d'=' -f2)
  RELEASE=$(grep "DD_RELEASE" "$PROFILE_FILE"|cut -d'=' -f2)
}

# Clone the project
_project_clone() {
  if [ -n "$1" ]; then
    release=$1
  else
    message_clone_latest=$(_show_confirm_message "Clone the latest version of DefectDojo ($DD_RELEASE_LATEST)? [Y/n] " "y")
    if [ -z "$message_clone_latest" ]; then
      release=""
      while [ -z "$release" ]; do
        read -r -p "Enter release version: " choice_profile_selected_release
        release=$(curl  -s "$DD_REPO_API/tags"|jq -r ".[]|select( .name == \"$choice_profile_selected_release\" ).name")
        if [ -z "$release" ]; then
          _show_message "$choice_profile_selected_release is not a valid version!" 1
        fi
      done
    else
      release=$DD_RELEASE_LATEST
    fi
  fi
  # Clone the DefectDojo project with the release selected
  _show_message "Clone the DefectDojo project ($release)"
  rm -rf "$DD_FOLDER" && git clone --depth 1 --branch "$release" "$DD_REPO"
}

# Initialize the project
_project_init() {
  option=$1
  # Clone DefectDojo project if the folder not exist
  if [ ! -d "$DD_FOLDER" ]; then
    _project_clone
  fi
  # Initialize the default profile
  if [ "$option" = "--install-auto" ]; then
    if [ -f "$PROFILE_FILE" ]; then
      message="Currently, a profile file is already configured. Do you want to use it? [Y/n] "
      use_profile_file=$(_show_confirm_message "$message" "y")
      if [ -z "$use_profile_file" ]; then
        # backup the current file
        mv -f "$PROFILE_FILE" "$(date +'%Y%m%d_%H%M')_$PROFILE_FILE"
        _profile_create_default
      fi
    else
      _profile_create_default
    fi
  # Initialize the profile if the file not exist
  elif [ ! -f "$PROFILE_FILE" ]; then
      message="Currently, no profile is configured. Do you want to use choose one? [Y/n] "
      choice_profile=$(_show_confirm_message "$message" "y")
      if [ -n "$choice_profile" ]; then
        _profile_create
      else
        _show_message "Please configure a profile before starting the application!" 1
        exit 1
      fi
  fi
  _profile_init
  _show_message "The project is configured with the $PROFILE profile and the release $RELEASE"
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

# Update the admin password
_update_admin_password() {
  docker-compose --log-level ERROR -f "$DD_FOLDER/docker-compose.yml" exec "$DD_CONTAINER_ADM" bash -c "/app/manage.py changepassword admin"
}

# Update new app version
_update_release() {
  _profile_init
  _check_release_update
}

# Update the token API
_update_token() {
  command="/app/manage.py drf_create_token admin 2> /dev/null"
  docker-compose --log-level ERROR -f "$DD_FOLDER/docker-compose.yml" exec "$DD_CONTAINER_ADM" bash -c "$command"
}

# Display help :)
display_help() {
  if [ "$1" = "start" ]; then
   _show_message "Usage: $0 start [--install-auto]" >&2
  elif [ "$1" = "stop" ]; then
    _show_message "Usage: $0 stop [--remove]" >&2
  elif [ "$1" = "show" ]; then
    _show_message "Usage: $0 show {status|release|env|token|logs}" >&2
  elif [ "$1" = "update" ]; then
    _show_message "Usage: $0 update {release|token|password}" >&2
  else
    _show_message "Usage: $0 {start|stop|show|update}" >&2
  fi
  echo
  exit 1
}

# Starting docker compose with the profile postgres-redis
start() {
  option=$1
  app_status=$(_app_status)
  first_start=0
  # Check the application status
  if [ "$app_status" = "up" ]; then
    _show_message "Application is already started!"
    exit 0
  fi
  if [ "$app_status" = "down" ]; then
    first_start=1
  fi
  _project_init "$option"
  if [ ! "$option" = "--install-auto" ]; then
    _check_release_update
  fi
  # Build DefectDojo docker images (=~ 4min) : defectdojo-nginx, defectdojo-django
  if [ $first_start -eq 1 ]; then
    _show_message "Image building..."
    docker-compose -f "$DD_FOLDER/docker-compose.yml" --profile "$PROFILE" --env-file "profile.env" build
  fi
  _show_message "Starting application..."
  docker-compose -f "$DD_FOLDER/docker-compose.yml" --profile "$PROFILE" --env-file "profile.env" up --no-deps -d
  _waiting_start
  # Creating a token on first start, and show credentials
  if [ $first_start -eq 1 ]; then
    _update_token
    admin_password=$(docker-compose --log-level ERROR -f "$DD_FOLDER/docker-compose.yml" logs initializer\
        |grep "Admin password:"|grep -v "Initialization"|awk '{ print $5 }')
    local_ip=$(ifconfig|grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*'|grep -Eo '([0-9]*\.){3}[0-9]*'|grep -v '172.*'|grep -v '127.*')
    _show_message "Done! You can access to the web interface at this address: http://$local_ip:8080, with this credentials (save them):"
    echo -e "\033[0;32madmin_user:\033[0m admin"
    echo -e "\033[0;32madmin_password:\033[0m $admin_password"
  else
    _show_message "Done!"
  fi
  exit 0
}

# Stop/remove DefectDojo containers
stop() {
  option=$1
  _profile_init
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
  exit 0
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
  # show release
  if [ "$1" = "release" ]; then
    if [ ! -d "$DD_FOLDER" ]; then
      _show_message "Project DefectDojo not exist, have you already started the application?" 1
    else
      _profile_init
    fi
    _show_message "Current release: $RELEASE"
    _show_message "Latest release: $DD_RELEASE_LATEST"
  fi
  # show environment variables
  if [ "$1" = "env" ]; then
    _profile_init
    _show_message "Environment variables"
    grep -v "DD_DATABASE_PASSWORD" "profile.env"|grep -v 'DD_TEST_DATABASE_URL'|grep -ve '^$'
  fi
  # show api token
  if [ "$1" = "token" ]; then
    command="/app/manage.py dumpdata --skip-checks authtoken.token 2> /dev/null"
    token=$(docker-compose --log-level ERROR -f "$DD_FOLDER/docker-compose.yml" exec "$DD_CONTAINER_ADM" bash -c "$command"|jq -r '.[0].pk')
    echo "TOKEN: $token"
  fi
  # Shown container logs
  if [ "$1" = "logs" ]; then
    app_status=$(_app_status)
    if [ ! "$app_status" = "up" ]; then
      _show_message "Application is not started!"
    else
      docker-compose --log-level ERROR -f "$DD_FOLDER/docker-compose.yml" logs -f "$DD_CONTAINER_ADM"
    fi
  fi
  exit 0
}

update() {
  if [ "$1" = "release" ]; then
    _update_release
  fi
  if [ "$1" = "token" ]; then
    _update_token
  fi
  if [ "$1" = "password" ]; then
    _update_admin_password
  fi
  exit 0
}

# Script variables
DD_REPO="https://github.com/DefectDojo/django-DefectDojo"
DD_REPO_API="https://api.github.com/repos/DefectDojo/django-DefectDojo"
DD_FOLDER="$(pwd)/$(echo $DD_REPO|rev|cut -d"/" -f1|rev)"
DD_RELEASE_LATEST=$(curl -s "$DD_REPO_API/releases/latest"|jq -r .tag_name)
DD_CONTAINER_ADM=celerybeat

PROFILE_FILE="profile.env"
PROFILE_DEFAULT_FOLDER="$DD_FOLDER/docker/environments"
PROFILE_DEFAULT=4 # postgres-redis

## Menu
options=$#
if [ $options -eq 0 ]; then
  display_help
else
  case "$1" in
    start)
      option=$2
      if [ $options -eq 2 ]; then
        if [ ! "$option" = "--install-auto" ]; then display_help start; fi
      elif [ ! $options -eq 1 ]; then
        display_help start
      fi
      start "$option"
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
        if [[ ! $2 =~ status|release|env|token|logs ]]; then display_help show; fi
        show "$2"
      fi
    ;;
    update)
      if [ ! $options -eq 2 ]; then
        display_help update
      else
        if [[ ! $2 =~ release|token|password ]]; then display_help update; fi
        update "$2"
      fi
    ;;
    shortlist)
      echo start stop show update shortlist
    ;;
    *)
      display_help
      ;;
  esac
fi
