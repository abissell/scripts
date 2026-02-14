#!/bin/sh

. ./scripts/sh/common.sh
. ./scripts-y/sh/common.sh

ensure_working_directory "${HOME}"

read -p 'Enter the URL from which to download the Neovim tar.gz: ' location

run_with_prompt 'rm -rf /tmp/nvim-tar && rm -rf /tmp/nvim-extracted'
run_with_prompt 'mkdir -p /tmp/nvim-tar'
run_with_prompt "wget ${location} -P /tmp/nvim-tar"
run_with_prompt "wget ${location}.sha256sum -P /tmp/nvim-tar"
filename="$(find /tmp/nvim-tar -maxdepth 1 -mindepth 1 | grep -v sha256)"
cd /tmp/nvim-tar && sha256sum -c "${filename}.sha256sum"
if [ $? -eq 0 ]; then
  echo 'sha256 checksum succeeded'
  cd "${HOME}"
else
  echo 'sha256 checksum failed! Verify download manually'
  exit 1
fi
press_enter_to_continue
run_with_prompt 'mkdir -p /tmp/nvim-extracted'
run_with_prompt "tar -zxvf ${filename} --directory /tmp/nvim-extracted"
nvim_dirname="$(basename $(find /tmp/nvim-extracted -maxdepth 1 -mindepth 1))"
echo "Parsed nvim_dirname ${nvim_dirname} from extracted directory"
run_with_prompt "mkdir -p ${HOME}/.local/lib/nvim/"

install_location="${HOME}/.local/lib/nvim/${nvim_dirname}"
if [ -d "${install_location}" ]; then
  echo "Found prior installation was already present at ${install_location}"
  backup_location="${HOME}/.local/lib/nvim/${nvim_dirname}_bak"
  [ -d backup_location ] && echo "Also found installation at ${backup_location}, backup will overwrite it!"
  echo 'Prompting for prior installation backup:'
  run_with_prompt "mv ${install_location} ${HOME}/.local/lib/nvim/${nvim_dirname}_bak"
fi

run_with_prompt "mv /tmp/nvim-extracted/${nvim_dirname} ${HOME}/.local/lib/nvim/"

run_with_prompt "ln -s ${install_location}/bin/nvim ${HOME}/.local/bin/nvim"

echo 'Installed Neovim version:'
nvim --version
