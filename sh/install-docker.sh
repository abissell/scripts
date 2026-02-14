#!/bin/sh

. ./scripts/sh/common.sh
. ./scripts-y/sh/common.sh

ensure_working_directory "${HOME}"

run_with_prompt 'sudo xbps-install docker docker-cli'

run_with_prompt 'sudo ln -s /etc/sv/docker /var/service/docker'

run_with_prompt 'sudo groupadd docker'
user="$(whoami)"
run_with_prompt "sudo usermod -aG docker ${user}"

echo 'Done, you may need to restart the Docker service or reboot for changes to take effect.'
