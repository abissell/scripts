#!/bin/sh

. scripts-y/sh/install-void/common.sh
ensure_working_directory '/root'
ensure_root

echo
echo "Running 'makewhatis' to generate the apropros"
echo 'database for searching man pages'
makewhatis
echo 'Symlinking dhcpcd to /var/service to enable it'
run_with_prompt 'ln -s /etc/sv/dhcpcd /var/service'
echo

read -p "Run 'bootstrap-wpa_supplicant.sh'? " yn
case $yn in
  [Yy]* ) sh scripts-y/sh/install-void/bootstrap-wpa_supplicant.sh;;
  * ) echo "Ok, skipping.";;
esac
echo
run_with_prompt 'ping -c 1 repo-default.voidlinux.org'
echo
echo 'If ping did not succeed, exit script and configure networking'
echo
echo "Running 'xbps-install -Su' twice to get pkg manager up to date ..."
xbps-install -Su
xbps-install -Su
echo '... updating xbps succeeded.'
echo
read -p 'Enter username for non-root user to be added: ' user
echo
# -m creates the home directory
useradd -m $user
passwd $user
usermod -a -G wheel $user
echo "User $user is now in groups $(groups $user)"
echo
echo "While still root, run 'visudo'"
echo 'and uncomment the line:'
echo '# %wheel ALL=(ALL) ALL'
echo
echo 'Once done, initial bootstrap is complete!'
echo "Recommend rebooting ('shutdown -r now') at this point."
