#!/bin/sh

. ./scripts/sh/common.sh
. ./scripts-y/sh/common.sh

ensure_working_directory "${HOME}"

read -p 'Enter the URL from which to download the JDK tar.gz: ' location

run_with_prompt 'rm -rf /tmp/jdk-tar && rm -rf /tmp/jdk-extracted'
run_with_prompt 'mkdir -p /tmp/jdk-tar'
run_with_prompt "wget ${location} -P /tmp/jdk-tar"

read -p 'Enter the URL from which to fetch SHA1SUMS: ' sha1sums_location
run_with_prompt "wget ${sha1sums_location} -P /tmp/jdk-tar"
filename="$(find /tmp/jdk-tar -maxdepth 1 -mindepth 1 | grep -v SHA1)"
echo 'Verify checksums:'
sha1sum "${filename}"
cat /tmp/jdk-tar/SHA1SUMS | grep "$(basename ${filename})"
press_enter_to_continue
run_with_prompt 'mkdir -p /tmp/jdk-extracted'
run_with_prompt "tar -xf ${filename} --directory /tmp/jdk-extracted"
jdk_dirname="$(basename $(find /tmp/jdk-extracted -maxdepth 1 -mindepth 1))"
echo "Parsed jdk_dirname ${jdk_dirname} from extracted directory"
run_with_prompt "mkdir -p ${HOME}/.local/lib/jvm/"
run_with_prompt "mv /tmp/jdk-extracted/${jdk_dirname} ${HOME}/.local/lib/jvm/"

if [ ! -L "${HOME}/.local/lib/jvm/default" ]; then
  echo 'Checking current Java version.'
  if java --version; then
    echo 'Found some Java already installed, not attempting to manage PATH via symlinks.'
    exit 1
  fi
  echo 'Found no default JVM symlink, creating one and adding it to PATH:'
  echo "Symlinking to ${HOME}/.local/lib/jvm/${jdk_dirname}"
  run_with_prompt "cd ${HOME}/.local/lib/jvm && ln -s ${jdk_dirname} default && ls -lah . && cd ${HOME}"
  shell_rc_filename=''
  pass_back_shell_rc_filename shell_rc_filename
  echo "Found shell_rc_filename ${shell_rc_filename}"
  echo "Adding section to update PATH to ${shell_rc_filename}, you should review after script exits."
  press_enter_to_continue
  echo >> "${shell_rc_filename}" && tee -a "${shell_rc_filename}" > /dev/null << 'RC'
export PATH="${HOME}/.local/lib/jvm/default/bin:${PATH}"
RC
else
  current_version="$(java --version | head -1 | cut -d' ' -f2)"
  if prompt "Parsed current Java version ${current_version}, would you like to replace it with ${jdk_dirname}?"; then
    run_with_prompt "cd ${HOME}/.local/lib/jvm && ln -s ${jdk_dirname} default && ls -lah . && cd ${HOME}"
  else
    echo 'Okay, leaving the current version in place.'
  fi
fi

rm -rf /tmp/jdk-extracted
rm -rf /tmp/jdk-tar
