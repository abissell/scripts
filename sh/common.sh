#!/bin/sh

# common.sh
# Copyright (C) 2023 Andrew Bissell
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

ensure_working_directory() {
  local wd="$(pwd)"
  local required="$1"
  if [ "$wd" != "$required" ]; then
    echo "Running from $wd, must run script from directory $required !"
    exit 1
  fi
}

ensure_root() {
  if [ "$(whoami)" != "root" ]; then
    echo "ERROR: Must run this script as root!"
    echo "Without 'sudo', become root with 'su -'."
    exit 1
  fi
}

prompt() {
  read -p "$1 " yn
  case $yn in
    [Yy]* )
      return 0
    ;;
    * )
      return 1
    ;;
  esac
  exit 1
}

run_with_prompt() {
  local command="$1"
  echo
  if prompt "Execute: '$command' ?"; then
    eval "$command"
    echo && echo "Command '$command' succeeded."
    return 0
  else
    echo "Ok, skipped."
    return 1
  fi
}

press_enter_to_continue() {
  printf "%s " "Press Enter to continue"
  read ans
}

reboot_for_changes() {
  local changes="$1"
  local reboot_command="$2"
  echo
  echo "Reboot needed for ${changes} to take effect."
  read -p "Would you like to reboot now? " yn
  case $yn in
    [Yy]* ) echo "Rebooting using command '${reboot_command}'..." && sleep 3 && eval "${reboot_command}" && sleep 5;;
    * ) echo "Ok, proceeding without reboot.";;
  esac
  echo
}

add_line_to_file() {
  local line="$1"
  local filename="$2"
  run_with_prompt "echo '${line}' >> ${filename}"
}

add_line_to_file_if_not_present() {
  local line="$1"
  local filename="$2"
  echo
  echo "Adding line: '${line}' to file ${filename} if not present:"
  if [ -f "$filename" ]; then
    if grep -q "${line}" "${filename}"; then
      echo "Line was already in file, will not add it."
      echo
    else
      echo "File was found but line was not in file."
      echo "Adding the line to the file."
      add_line_to_file "${line}" "${filename}"
    fi
  else
    echo "File was not found, will add line and chown the file to user ${user}"
    add_line_to_file "${line}" "${filename}"
    run_with_prompt "chown ${user}:${user} ${filename}"
  fi
}

set_step() {
  mkdir -p tmp
  local newstep="$1"
  echo "${newstep}" > tmp/step.txt
  step="${newstep}"
}
