#!/bin/bash
EMERGE_DEEP_UPDATE="emerge --verbose --update --deep --newuse --changed-use --with-bdeps=y --keep-going"

# Color options
NC='\033[0m' # No Color
GREEN='\033[0;32m'
GREY='\033[30;1m'
RED='\033[0;31m'

# Echo prefixes
FAILURE="[$RED!$NC]"
INFO="[$GREY*$NC]"
SUCCESS="[$GREEN+$NC]"

# -h | --help
function usage() { 
  if [[ $EUID -ne 0 ]]; then
    echo -e "$FAILURE This script must be run as root"
  else
    echo -e "$SUCCESS This script must be run as root"
  fi
  echo "Usage: $0 [--update] [--full-update]" 1>&2;
  exit 1
}

function update_layman_repositories() {
  echo -e "$INFO Updating Layman repositories..."
  if layman -S 1>/dev/null ; then
    echo -e "$SUCCESS Layman repositories updated!"
  else
    echo -e "$FAILURE Error occurred when updating Layman repositories"
  fi
}

function update_portage_repositories() {
  echo -e "$INFO Syncing Portage..."
  portage_update_available="$(emerge --sync | tee /dev/null | grep 'An update to portage is available')"

  # Was updating successful?
  if [[ "$?" -eq 0 ]]; then
    echo -e "$SUCCESS Portage repositories updated!"
  else
    echo -e "$FAILURE Error occurred when updating Portage repositories"
  fi

  # Update Portage automatically if an update is available
  if [[ $portage_update_available ]]; then
    echo -e "$INFO Updating Portage..."
    emerge --oneshot sys-apps/portage
  fi
}

# --update
function update_package_repositories() {
  update_layman_repositories
  update_portage_repositories
}

# --important
function important_packages_update() {
  echo -e "$INFO Updating important packages..."
  #$EMERGE_DEEP_UPDATE --oneshot vim linux-firmware linux-headers gentoo-sources btop htop firefox-bin nvidia-drivers
  $EMERGE_DEEP_UPDATE --oneshot gentoo-sources
  echo -e "$SUCCESS Important packages updated!"
}

# --full-update
function full_system_update() {
  echo -e "$INFO Updating the full system..."
  $EMERGE_DEEP_UPDATE @world
  echo -e "$SUCCESS Updated the full system!"
}

### MAIN
if [[ "$1" =~ ^-h|--help$ || $EUID -ne 0 ]]; then usage; fi # Print usage message and exit

# --update argument
if [[ "$@" == *"--update"* ]]; then
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
elif [[ "$@" == *"--full-update"* ]]; then
  full_system_update

# Ask user if no update related command line arguments are given
else
  echo -ne "Would you like to update important packages? (y/N): "
  read update_important_packages
  
  if [[ "$update_important_packages" =~ ^Y|y$ ]]; then
    important_packages_update
  fi
  echo -ne "Would you like to perform full system update? (y/N): "
  read update_full_system
  
  if [[ "$update_full_system" =~ ^Y|y$ ]]; then
    update_package_repositories
  fi
fi
