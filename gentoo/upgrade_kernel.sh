#!/bin/sh

# Color options
NC='\033[0m' # No Color
GREEN='\033[0;32m'
GREY='\033[30;1m'
RED='\033[0;31m'

# Echo prefixes
FAILURE="[$RED!$NC]"
INFO="[$GREY*$NC]"
SUCCESS="[$GREEN+$NC]"

# Initialize variables
COMMAND_LINE_PARAMETERS="$@"
CPU_CORES="$(cat /proc/cpuinfo | grep '^processor' | wc -l)" # Number of CPU cores
OLD_KERNEL_VERSION=$(uname -r) # Example: 5.14.6-gentoo
OLD_KERNEL_DIRECTORY="/usr/src/linux-$OLD_KERNEL_VERSION" # Example: /usr/src/linux-5.14.6-gentoo
SCRIPT_NAME="$(basename $0)"

# -h | --help
function usage() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "$FAILURE This script must be run as root"
    exit 1
  else
    echo -e "$SUCCESS This script must be run as root\n"
  fi

  echo """
$SCRIPT_NAME is a script to automate kernel deployment process.
This script can automatically configure and install the newest kernel version installed from Portage.
The script will update the Grub configuration and /usr/src/linux symlink to point to the new version.
It can also reinstall the kernel modules which are installed from Portage for the new kernel version.

Command Line Parameters:

  Every command line parameter has a skip variant except for --all and --verbose
  For example to skip compiling the new kernel use --no-compile

  --all: Run all functions without asking for confirmation
  --compile: Compile new kernel without asking for confirmation
  --install: Run 'make oldconfig' command without asking for confirmation
  --module-rebuild: Reinstall kernel modules installed from Portage without asking for confirmation
  --oldconfig: Run 'make oldconfig' command without asking for confirmation
  --reboot: Reboot the system after installing the new kernel without asking for confirmation
  --verbose: Add verbosity to output
  """
  exit 0
}

function get_newest_kernel_version() {
  echo -e "$INFO Current kernel version: $OLD_KERNEL_VERSION"
  echo -e "$INFO Fetching kernel versions from Portage..."
  
  NEW_KERNEL_VERSION="$(equery list -po gentoo-sources | tail -1 | cut -d "-" -f 4)-gentoo"
  
  if [[ $NEW_KERNEL_VERSION == "$OLD_KERNEL_VERSION" ]]; then
    echo -e "$SUCCESS Newest kernel version is already installed!\n"
    exit 0
  else
    echo -e "$SUCCESS New kernel version found: $NEW_KERNEL_VERSION\n"
  fi
}

# Parameter $1 ==> Message to be printed
function echo_if_verbose() { 
  message="$1"
  if [[ "$COMMAND_LINE_PARAMETERS" =~ "--verbose" ]]; then
    echo -e "$INFO $message"
  fi
}

# Args: updated --> String
function test_command_status() {
  cmd="$1"

  # Was updating successful?
  if [[ "$?" -eq 0 ]]; then
    echo -e "$SUCCESS Command '$cmd' executed successfully!\n"
  else
    echo -e "$FAILURE Error occurred when executing '$cmd'!"
  fi
}

function execute_and_test() {
  cmd="$1"
  echo -e "$INFO Running command '$cmd'"
  $cmd
  test_command_status "$cmd"
}

# run_command cmd allow_parameter skip_parameter
# cmd: Command to run
# allow_parameter: Command line parameter which forces cmd to happen
# skip_parameter: Command line parameter which makes the program skip this cmd
# Return values: 1 => Command was executed, 0 => Command was skipped
function run_command() {
  cmd="$1"
  allow_parameter="$2"
  skip_parameter="$3"

  if [[ "$COMMAND_LINE_PARAMETERS" =~ "$allow_parameter" || ( "$COMMAND_LINE_PARAMETERS" =~ --all|-a  && "$cmd" != "reboot" ) ]]; then
    execute_and_test "$cmd"
    return 1
  elif [[ "$COMMAND_LINE_PARAMETERS" != *"$skip_parameter"* ]]; then
    echo -ne "Would you like to run '$cmd' command? (y/N): "
    read execute_command
  
    if [[ "$execute_command" =~ ^Y|y$ ]]; then
      execute_and_test "$cmd"
      return 1
    fi
  fi
  return 0
}

function update_grub() {
  dev="/dev/nvme0n1p2" # Device where Grub is installed
  mount_location="/mnt/arch" # Where dev will be mounted
  grub_location="$mount_location/boot/grub/grub.cfg"

  update_target="Grub configuration"
  echo -e "$INFO Updating $update_target..."

  echo_if_verbose "Mounting $dev to $mount_location" # -v | --version
  mount $dev $mount_location 

  echo_if_verbose "Changing grub.cfg to use the new kernel version"
  sed -i "s/$OLD_KERNEL_VERSION/$NEW_KERNEL_VERSION/g" $grub_location

  echo_if_verbose "Un-mounting $dev"
  umount $dev

  echo -e "$SUCCESS Updated $update_target!\n"
}

function update_kernel_symlink() {
  update_target="kernel symlink"
  echo -e "$INFO Updating $update_target..."
  
  echo_if_verbose "Removing old symlink /usr/src/linux"
  rm /usr/src/linux
  
  symlink_command="ln -s /usr/src/linux-$NEW_KERNEL_VERSION /usr/src/linux"
  echo_if_verbose "Creating new symlink /usr/src/linux...\nCommand: $symlink_command"
  $symlink_command

  echo -e "$SUCCESS Updated $update_target!\n"
}

### MAIN
if [[ "$1" =~ ^-h|--help$ || $EUID -ne 0 ]]; then usage; fi # Print usage message and exit

# Check if there is newer kernel version available on the system or in Portage
get_newest_kernel_version

NEW_KERNEL_DIRECTORY="/usr/src/linux-$NEW_KERNEL_VERSION"
cd $NEW_KERNEL_DIRECTORY

# Run 'make oldconfig' command if user allows it or uses argument --oldconfig
run_command "make oldconfig" "--oldconfig" "--no-oldconfig"

# Compile kernel if user allows it or uses argument --compile
run_command "make -j$CPU_CORES" "--compile" "--no-compile"
run_command "make -j$CPU_CORES modules_install" "--compile" "--no-compile"

# Install the kernel to /boot directory
run_command "make install" "--install" "--no-install"

# Do the following actions only if the new kernel was installed
if [[ "$?" == "1" ]]; then # run_command returns 1 if command was executed
  update_grub
  update_kernel_symlink
  echo -e "$SUCCESS Kernel $NEW_KERNEL_VERSION installed successfully!\n"
  
  echo_if_verbose "It is recommended to reinstall kernel modules installed from Portage"
  run_command "emerge -v @module-rebuild" "--module-rebuild" "--no-module-rebuild"

  echo_if_verbose "The system must be rebooted to use the new kernel"
  run_command "reboot" "--reboot" "--no-reboot"
fi
