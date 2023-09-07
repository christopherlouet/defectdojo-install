#!/usr/bin/env bash

NOCOLOR='\033[0m'
GREEN='\033[0;32m'
RED='\033[0;31m'
ORANGE='\033[0;33m'

# Print a message to STDOUT. You can customize the output by specifying a level.
#
# $1 - String messages that will be printed.
# $2 - An optional level (0: info, >0: error, <0: warn).
#
# Returns nothing.
show_message() {
  msg=$1
  level=$2
  # level=0: info message
  if [ -z "$level" ]; then
    level=0
    msg_start="$GREEN"
    msg_end="$NOCOLOR"
  fi
  # level>0: error message
  if [ -n "$level" ] && [ "$level" -gt 0 ]; then
    msg_start="$RED"
  fi
  # level<0: warn message
  if [ -n "$level" ] && [ "$level" -lt 0 ]; then
    msg_start="$ORANGE"
  fi
  echo -e "$msg_start$msg$msg_end"
}

# Read a confirm message and print a response ('y','') to STDOUT.
#
# $1 - String messages that will be prompted.
# $2 - Message to display if no answer is entered.
# $3 - Expected answer, used for unit test.
#
# Returns nothing.
show_confirm_message() {
  default_answer=$2
  test_answer=$3
  if [ -z "$test_answer" ]; then
    read -r -p "$1" answer
  else
    answer=$test_answer
  fi
  if [ -z "$answer" ]; then
    echo "$default_answer"
    exit
  fi
  case "$answer" in [yY][eE][sS]|[yY])
      echo "y"
      ;;
    *)
      echo ""
      ;;
  esac
}

"$@"
