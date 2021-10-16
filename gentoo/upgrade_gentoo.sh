#!/bin/bash

# Initialize global variables
COMMAND_LINE_PARAMETERS="$@"
EMERGE_DEEP_UPDATE="emerge --verbose --update --deep --newuse --changed-use --with-bdeps=y --keep-going"

# Color options
NC='\033[0m' # No Color
GREEN='\033[0;32m'
GREY='\033[30;1m'
RED='\033[0;31m'

# Echo prefixes
COMMAND="[CMD]"
FAILURE="[ $RED!$NC ]"
INFO="[ $GREY*$NC ]"
SUCCESS="[ $GREEN+$NC ]"


# -h | --help
function usage() { 
  if [[ $EUID -ne 0 ]]; then
    echo -e "$FAILURE This script must be run as root"
  else
    echo -e "$SUCCESS This script must be run as root"
  fi
  echo "Usage: $0 [--all] [--update] [--full-update]" 1>&2;
  exit 1
}

# Args: Command to be executed
function execute_command_verbose() {
  cmd="$1"
  if [[ "$COMMAND_LINE_PARAMETERS" =~ --verbose ]]; then
    echo -e "$COMMAND $cmd" # Print the command
  fi

  $cmd # Run the command
}

# Args: updated --> String
function test_update_status() {
  updated=$1

  # Was updating successful?
  if [[ "$?" -eq 0 ]]; then
    echo -e "$SUCCESS Updated $updated!\n"
  else
    echo -e "$FAILURE Error occurred when updating $updated"
  fi
}

function update_layman_repositories() {
  echo -e "$INFO Updating Layman repositories..."
  execute_command_verbose "layman -S"
  test_update_status "Layman repositories"
}

function update_portage_repositories() {
  echo -e "$INFO Syncing Portage..."
  execute_command_verbose "emerge --sync"
}

# --update
function update_package_repositories() {
  update_layman_repositories
  update_portage_repositories
}

# --important
function important_packages_update() {
  echo -e "$INFO Updating important packages..."
  execute_command_verbose "$EMERGE_DEEP_UPDATE --oneshot portage vim linux-firmware linux-headers gentoo-sources btop htop firefox-bin nvidia-drivers"
  test_update_status "important packages"
}

# --full-update
function full_system_update() {
  echo -e "$INFO Updating the full system..."
  execute_command_verbose "$EMERGE_DEEP_UPDATE @world"
  test_update_status "full system"
}

### MAIN
if [[ "$1" =~ ^-h|--help$ || $EUID -ne 0 ]]; then usage; fi # Print usage message and exit

# --update argument
if [[ "$@" == *"--update"* || "$1" =~ ^-a|--all$ ]]; then
  update_package_repositories
else
  echo -ne "Would you like to update Layman and Portage package repositories? (y/N): "
  read update_repositories
  
  if [[ "$update_repositories" =~ ^Y|y$ ]]; then
    update_package_repositories
  fi
fi

# Check update related command line arguments
if [[ "$@" == *"--important"* ]]; then
  important_packages_update

elif [[ "$@" == *"--full-update"* || "$1" =~ ^-a|--all$ ]]; then
  full_system_update

# Ask user if no update related command line arguments are given
else
  echo -ne "Would you like to update important packages? (y/N): "
  read update_important_packages
  
  if [[ "$update_important_packages" =~ ^Y|y$ || "$1" =~ ^-a|--all$ ]]; then
    important_packages_update
  fi
  echo -ne "Would you like to perform full system update? (y/N): "
  read update_full_system
  
  if [[ "$update_full_system" =~ ^Y|y$ || "$1" =~ ^-a|--all$ ]]; then
    full_system_update
  fi
fi

update_kernel_script="kernel_upgrade.sh"

if [[ "$1" =~ ^-a|--all$ ]]; then
  $update_kernel_script $COMMAND_LINE_PARAMETERS
else
  echo -ne "Would you like to update the kernel to the newest version? (y/N): "
  read update_kernel
  if [[ "$update_kernel" =~ ^Y|y$ ]]; then
    $update_kernel_script $COMMAND_LINE_PARAMETERS
  fi
fi
