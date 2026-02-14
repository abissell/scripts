#!/bin/sh

. ./scripts/sh/common.sh

ensure_working_directory "${HOME}"

run_with_prompt 'curl https://pyenv.run | bash'

shell_rc_file_base=$(basename "${SHELL}")
case "${shell_rc_file_base}" in
  zsh)
    if [ -z "${ZDOTDIR}" ]; then
      zsh_files_path="${HOME}"
    else
      zsh_files_path="${ZDOTDIR}"
    fi

    shell_rc_file="${zsh_files_path}/.zshrc"
    shell_login_profile_file="${zsh_files_path}/.zprofile"
    ;;
  bash)
    shell_rc_file="${HOME}/.bashrc"
    shell_login_profile_file="${HOME}/.bash_profile"
    ;;
  *)
    echo "Couldn't determine rc and login profile files for ${SHELL}!"
    exit 1
    ;;
esac

if prompt "Confirm your shell rc file is: ${shell_rc_file}?"; then
  echo 'Ok.'
else
  echo 'You said no, exiting the script since we cannot complete the shell setup stage'
  exit 1
fi

if prompt "Confirm your shell login profile file is: ${shell_login_profile_file}?"; then
  echo 'Ok.'
else
  echo 'You said no, exiting the script since we cannot complete the shell setup stage'
  exit 1
fi

if grep -q 'PYENV_ROOT' "${shell_login_profile_file}"; then
  echo "PYENV_ROOT was already present in ${shell_login_profile_file}, will not update it"
else
  if [ -f "${shell_login_profile_file}" ]; then
    echo "Found file ${shell_login_profile_file} already exists, offering to add newline for spacing:"
    run_with_prompt "echo >> ${shell_login_profile_file}"
  fi

  tee -a "${shell_login_profile_file}" > /dev/null << 'PROFILE'
export PYENV_ROOT="${HOME}/.pyenv"
#!/bin/sh
[ -d "${PYENV_ROOT}/bin" ] && export PATH="${PYENV_ROOT}/bin:${PATH}"
eval "$(pyenv init -)"
PROFILE
echo 'appended to shell login profile file!'
fi

if grep -q 'pyenv virtualenv-init' "${shell_rc_file}"; then
  echo "pyenv virtualenv-init line was already present in ${shell_rc_file}, will not update it"
else
  if [ -f "${shell_rc_file}" ]; then
    echo "Found file ${shell_rc_file} already exists, offering to add newline for spacing:"
    run_with_prompt "echo >> ${shell_rc_file}"
  fi

  tee -a "${shell_rc_file}" > /dev/null << 'RC'
export PYENV_ROOT="${HOME}/.pyenv"
#!/bin/sh
[ -d "${PYENV_ROOT}/bin" ] && export PATH="${PYENV_ROOT}/bin:${PATH}"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
RC
fi

echo "Script completed, review changes to ${shell_login_profile_file} and ${shell_rc_file}"
echo 'and restart shell for changes to take effect.'
