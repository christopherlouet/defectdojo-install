#!/usr/bin/env bash

CURRENT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DD_REPO="https://github.com/DefectDojo/django-DefectDojo"
DD_REPO_API="https://api.github.com/repos/DefectDojo/django-DefectDojo"
DD_RELEASE_LATEST=$(curl -s "$DD_REPO_API/releases/latest"|jq -r .tag_name)
DD_FOLDER="$CURRENT_DIR/../$(echo $DD_REPO|rev|cut -d"/" -f1|rev)"

_show_message() {
  bash "$CURRENT_DIR/messages.sh" "show_message" "$@"
}

# Clone the DefectDojo project with the release selected
project_clone() {
  if [ -n "$1" ]; then
    release=$1
  else
    release=$DD_RELEASE_LATEST
  fi

  _show_message "Clone the DefectDojo project ($release)"

  _show_message "rm -rf $DD_FOLDER" -1
  rm -rf "$DD_FOLDER"

  _show_message "git clone --depth 1 --branch $release $DD_REPO $DD_FOLDER" -1
  git clone --depth 1 --branch "$release" "$DD_REPO" "$DD_FOLDER"
}

"$@"
