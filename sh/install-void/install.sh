#!/bin/sh

. scripts-y/sh/install-void/common.sh
ensure_working_directory "/home/$(logname)"

add_to_grub_cmdline() {
  local to_add=$1
  local grub_cmdline="$(cat /etc/default/grub | grep GRUB_CMDLINE_LINUX_DEFAULT | cut -d \" -f2)"
  run_with_prompt "sudo sed -i 's/${grub_cmdline}/${grub_cmdline} ${to_add}/' /etc/default/grub"
  run_with_prompt 'sudo update-grub'
  return 0
}

echo
user=$(logname)
read -p "Proceed with setup steps for user $user? " yn
case $yn in
  [Yy]* ) echo 'Ok, proceeding.';;
  * ) exit;;
esac
echo

step=' '
if [ -f 'tmp/step.txt' ]; then
  step=$(cat tmp/step.txt)
  echo "Last completed step: $step"
else
  echo 'Had not yet completed any steps.'
fi
press_enter_to_continue

run_with_prompt 'ping -c 1 repo-default.voidlinux.org && sudo xbps-install -Su'

if [ "${step}" = ' ' ]; then
  echo "Beginning 'chrony' step."
  run_with_prompt 'sudo xbps-install chrony'
  run_with_prompt 'sudo ln -s /etc/sv/chronyd /var/service/'
  echo "The date is now $(date)"
  set_step 'chrony'
else
  echo "Skipping the 'chrony' step since already completed."
fi
echo

if [ "${step}" = 'chrony' ]; then
  echo "Beginning 'nonfree' step."
  run_with_prompt 'sudo xbps-install void-repo-nonfree'
  set_step 'nonfree'
else
  echo "Skipping the 'nonfree' step since already completed."
fi
echo

if [ "${step}" = 'nonfree' ]; then
  echo "Beginning 'microcode' step."
  if [ $(lscpu | grep Vendor | grep -ic Intel) -eq 1 ]; then
    run_with_prompt 'sudo xbps-install intel-ucode'
    echo "Running 'dracut' to regenerate the initramfs."
    run_with_prompt 'sudo dracut --force'
    echo "After reboot, you can verify the microcode update in '/proc/cpuinfo'"
  fi
  set_step 'microcode'
  reboot_void_for_changes 'installed microcode'
else
  echo "Skipping the 'microcode' step since already completed."
fi
echo

if [ "${step}" = 'microcode' ]; then
  echo "Beginning 'basic-conf' step."
  run_with_prompt "sudo sed -i 's/#HARDWARECLOCK=/HARDWARECLOCK=/' /etc/rc.conf"
  if [ $(grep -ic 'lat9w-16' /etc/rc.conf) -eq 1 ]; then
    echo 'Accept following prompts to replace console font with 32pt Terminus'
    run_with_prompt 'sudo xbps-install terminus-font'
    run_with_prompt "sudo sed -i 's/lat9w-16/ter-i32n/' /etc/rc.conf"
    run_with_prompt "sudo sed -i 's/#FONT=/FONT=/' /etc/rc.conf"
  else
    echo 'ERROR: did not find expected single instance of lat9w-16 in /etc/rc.conf'
    echo 'Cannot update the font setting by replacing this entry'
    echo 'You may want to review the file and Void Linux rc-files documentation'
  fi
  read -p 'Would you like to change the hostname? ' yn
  case $yn in
    [Yy]* )
      read -p 'Enter the new desired hostname: ' newhost
      run_with_prompt "sudo echo ${newhost} > /etc/hostname"
      echo "The file /etc/hostname now contains: $(cat /etc/hostname)"
    ;;
    * )
      echo 'Ok, skipped.' && echo
    ;;
  esac
  run_with_prompt 'sudo ln -sf /usr/share/zoneinfo/UTC /etc/localtime'
  set_step 'basic-conf'
  reboot_void_for_changes 'changed font, hostname, and timezone'    
fi

if [ "${step}" = 'basic-conf' ]; then
  echo "Beginning 'capslock-remap' step"
  run_with_prompt 'sudo mkdir -p /etc/udev/hwdb.d && sudo cp configs-y/T470/linux/etc/udev/hwdb.d/90-remap.hwdb /etc/udev/hwdb.d/90-remap.hwdb'
  run_with_prompt 'sudo udevadm hwdb --update'
  set_step 'capslock-remap'
  reboot_void_for_changes "remapped CapsLock to L-Ctrl"
fi  

if [ "${step}" = 'capslock-remap' ]; then
  echo "Beginning 'cronie' step."
  run_with_prompt 'sudo xbps-install cronie'
  run_with_prompt 'sudo ln -s /etc/sv/cronie /var/service/'
  set_step 'cronie'
fi

if [ "${step}" = 'cronie' ]; then
  echo "Beginning 'ssd-trim' step."
  add_to_grub_cmdline 'rd.luks.allow-discards'
  echo "After reboot, try running 'fstrim' against '/' and '/home'"
  set_step 'ssd-trim'
  reboot_void_for_changes 'updated GRUB to enable TRIM on root device on LUKS'
fi

if [ "${step}" = 'ssd-trim' ]; then
  echo "Beginning 'ssd-trim-cron' step."
  echo "If TRIM configured correctly for LUKS the following should contain 'allow_discards':"
  echo
  sudo dmsetup table /dev/mapper/vg --showkeys
  echo
  echo "Setting up weekly TRIM cron job"
  run_with_prompt 'sudo mkdir -p /etc/cron.weekly'
  run_with_prompt "sudo cat <<HERE >> fstrim
#!/bin/sh

fstrim /
fstrim /home
HERE"
  run_with_prompt 'sudo chown root:root fstrim && sudo chmod u+x fstrim && sudo mv fstrim /etc/cron.weekly/'
  set_step 'ssd-trim-cron'
fi

if [ "${step}" = 'ssd-trim-cron' ]; then
  echo "Beginning 'dbus' step"
  run_with_prompt 'sudo xbps-install dbus'
  run_with_prompt 'sudo ln -s /etc/sv/dbus /var/service/'
  set_step 'dbus'
  reboot_void_for_changes 'installed and activated dbus service'
fi

if [ "${step}" = 'dbus' ]; then
  echo "Beginning 'apparmor' step"
  run_with_prompt 'sudo xbps-install apparmor'
  add_to_grub_cmdline 'apparmor=1 security=apparmor'
  set_step 'apparmor'
  reboot_void_for_changes 'installed AppArmor and configured on GRUB kernel cmdline'
fi

if [ "${step}" = 'apparmor' ]; then
  echo "Beginning 'lts-kernel' step"
  run_with_prompt 'sudo xbps-install linux-lts linux-lts-headers'
  set_step 'lts-kernel'
  reboot_void_for_changes 'installed linux-lts kernel series'
fi

if [ "${step}" = 'lts-kernel' ]; then
  echo "Beginning 'tlp' step"
  run_with_prompt 'sudo xbps-install tlp'
  run_with_prompt 'sudo ln -s /etc/sv/tlp /var/service/'
  set_step 'tlp'
fi

if [ "${step}" = 'tlp' ]; then
  echo "Beginning 'graphics-prep' step"
  run_with_prompt 'sudo xbps-install linux-firmware-intel'
  run_with_prompt 'sudo xbps-install mesa-dri'
  run_with_prompt 'sudo xbps-install vulkan-loader mesa-vulkan-intel'
  run_with_prompt 'sudo xbps-install intel-video-accel'
  set_step 'graphics-prep'
  reboot_void_for_changes 'installed graphics prep packages'
fi

if [ "${step}" = 'graphics-prep' ]; then
  echo "Beginning 'essential-tools' step"
  run_with_prompt 'sudo xbps-install curl git'
  set_step 'essential-tools'
fi

if [ "${step}" = 'essential-tools' ]; then
  echo "Beginning 'xorg' step"
  run_with_prompt 'sudo xbps-install xorg-minimal'
  set_step 'xorg'
fi

if [ "${step}" = 'xorg' ]; then
  echo "Beginning 'fonts' step"
  run_with_prompt 'sudo xbps-install xorg-fonts'
  run_with_prompt 'sudo xbps-install nerd-fonts'
  run_with_prompt 'sudo xbps-install font-ibm-type1'
  run_with_prompt 'sudo xbps-install freefont-ttf'
  run_with_prompt 'mkdir -p .fonts'
  run_with_prompt 'cp -R configs-y/fonts/* .fonts/'
  run_with_prompt 'fc-cache -fv'
  set_step 'fonts'
fi

if [ "${step}" = 'fonts' ]; then
  echo "Beginning 'xorg-fonts' step"
  sh scripts-y/sh/install-void/configure_xorg_fonts.sh
  set_step 'xorg-fonts'
fi

if [ "${step}" = 'xorg-fonts' ]; then
  echo "Beginning 'install-i3wm' step"
  run_with_prompt 'sudo xbps-install i3 i3lock i3status'
  run_with_prompt 'sudo xbps-install dmenu'
  add_line_to_file_if_not_present '/usr/bin/i3' '.xinitrc'
  echo 'The contents of .xinitrc are now:'
  echo
  cat .xinitrc
  echo
  set_step 'install-i3wm'
fi

if [ "${step}" = 'install-i3wm' ]; then
  echo "Beginning 'zsh' step"
  run_with_prompt 'sudo xbps-install zsh'
  run_with_prompt 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
  echo '' >> $HOME/.zshrc
  xdg_runtime_dir="/run/user/$(id -u)"
  run_with_prompt "sudo mkdir -p ${xdg_runtime_dir}"
  run_with_prompt "sudo chown $USER:$USER ${xdg_runtime_dir}"
  run_with_prompt "sudo chmod 700 ${xdg_runtime_dir}"
  echo "export XDG_RUNTIME_DIR='${xdg_runtime_dir}'" >> $HOME/.zshrc
  run_with_prompt "mkdir -p $HOME/.local/share"
  echo "export XDG_DATA_HOME='$HOME/.local/share'" >> $HOME/.zshrc
  run_with_prompt "mkdir -p $HOME/.config"
  echo "export XDG_CONFIG_HOME='$HOME/.config'" >> $HOME/.zshrc
  run_with_prompt "mkdir -p $HOME/.local/state"
  echo "export XDG_STATE_HOME='$HOME/.local/state'" >> $HOME/.zshrc
  run_with_prompt "mkdir -p $HOME/.local/bin"
  echo "export PATH='$HOME/.local/bin:$PATH'" >> $HOME/.zshrc
  echo "sudo mkdir -p ${xdg_runtime_dir}" >> $HOME/.zshrc
  echo "sudo mkdir -p /run/user/$(id -u) && sudo chown $user:$user /run/user/$(id -u) && sudo chmod 700 /run/user/$(id -u)" >> $HOME/.zshrc
  set_step 'zsh'
fi

if [ "$step" = 'zsh' ]; then
  echo "Beginning 'configure-x-console' step."
  run_with_prompt 'sudo xbps-install rxvt-unicode urxvt-perls xdpyinfo'
  echo 'Configuring shell autostart script to export urxvt as the default terminal.'
  read -p "What is your shell autostart script filename (e.g. '.zshrc')? " autostart_filename
  if [ -f "$autostart_filename" ]; then
    echo "Found autostart script at $autostart_filename."
    if [ $(grep -c 'export TERMINAL' $autostart_filename) -ne 0 ]; then
      echo "Found TERMINAL export was already in file, will not add it."
    else
      echo "Adding lines to export TERM and TERMINAL environment variables."
      add_line_to_file '
# use 256 color xterm
export TERM="xterm-256color"
# set urxvt as default terminal
export TERMINAL="/usr/bin/urxvtc"' "${autostart_filename}"
    fi
  else
    echo "Could not find shell autostart script at $autostart_filename !"
    echo "Please configure shell correctly, check filename and rerun this setup script."
    printf "%s " "Press Enter to exit"
    read ans
    exit 1
  fi
  echo "Adding line to start urxvtd daemon on x startup"
  add_line_to_file_if_not_present "urxvtd -q -o -f" ".xinitrc"
  run_with_prompt 'sudo xbps-install xrdb'
  run_with_prompt "echo 'xrdb -merge ~/.Xresources' >> .xinitrc"
  echo "Copying Xresources setup file to ~/.Xresources"
  echo "Note! Some defaults in this file may need to be adjusted."
  echo "To find the correct DPI for the file, start an X session"
  echo "with 'startx' and run 'xdpyinfo | grep -B2 resolution'"
  run_with_prompt "cp configs/xorg/Xresources .Xresources && chown $user:$user .Xresources"
  set_step "configure-x-console"
else
  echo "Skipping the 'configure-x-console' step since already completed."
fi
echo

if [ "${step}" = 'configure-x-console' ]; then
  echo "Beginning 'i3wm-config' step."
  echo
  echo -n "Setting up i3 config file with Win modkey and vim-style movement defaults ... "
  cp /etc/i3/config $HOME/.config/i3
  sed -i 's/# Font for window titles/set $mod Mod4\n\n# Font for window titles/g' .config/i3/config
  sed -i 's/Mod1/$mod/g' .config/i3/config
  sed -i 's/set $up l/set $up k/g' .config/i3/config
  sed -i 's/set $down k/set $down j/g' .config/i3/config
  sed -i 's/set $left j/set $left h/g' .config/i3/config
  sed -i 's/set $right semicolon/set $right l/g' .config/i3/config
  sed -i 's/exec i3-config-wizard//g' .config/i3/config
  sed -i 's/bindsym $mod+h split h/bindsym $mod+s split h/g' .config/i3/config
  sed -i 's/bindsym $mod+s layout stacking/bindsym $mod+t layout stacking/g' .config/i3/config
  echo "Note that you can set the font size for status bar and window labels"
  echo "by changing the line 'font pango:monospace 8' ."
  chown $user:$user $HOME/.config/i3/config
  echo "Succeeded."
  echo
  set_step 'i3wm-config'
  reboot_void_for_changes 'configuration of i3'
fi

if [ "${step}" = 'i3wm-config' ]; then
  echo "Beginning 'system-pkgs' step."
  run_with_prompt "sudo xbps-install $(cat configs-y/system-pkgs)"
  run_with_prompt "sudo xbps-install $(cat configs-y/void/system-pkgs)"
  set_step 'system-pkgs'
fi

if [ "${step}" = 'system-pkgs' ]; then
  echo "Beginning 'audio' step."
  run_with_prompt "sudo usermod -a -G audio ${user}"
  sudo xpbs-install alsa-utils
  sudo ln -s /etc/sv/alsa/ /var/service/
  sudo xbps-install pulseaudio
  sudo xbps-install alsa-plugins-pulseaudio
  set_step 'audio'
fi




##### REFERENCE METHODS FROM FREEBSD INSTALL:

if [ "$step" = "i3wm" ]; then
  echo "Beginning 'essential-progs' step."
  run_with_prompt "pkg install rsync"
  run_with_prompt "pkg install lsof"
  run_with_prompt "pkg install ripgrep"
  run_with_prompt "pkg install neovim"
  run_with_prompt "pkg install scrot"
  run_with_prompt "pkg install xclip"
  run_with_prompt "pkg install vlc"
  set_step "essential-progs"
else
  echo "Skipping the 'essential-progs' step since already completed."
fi
echo

if [ "$step" = "essential-progs" ]; then
  echo "Beginning dev-setup step."
  run_with_prompt "mkdir -p .config && cp -R configs/nvim .config"
  run_with_prompt "cat configs/freebsd/shrc-append >> .shrc"
  run_with_prompt "sh scripts/sh/apply-configs-updates.sh"
  set_step "dev-setup"
else
  echo "Skipping the dev-setup step since already completed."
fi
echo

if [ "$step" = "essential-progs" ]; then
    echo "Beginning 'java-dev' step."
    run_with_prompt "pkg install openjdk19"
    if prompt "Clone eclipse.jdt.ls repo and build from source?"; then
        run_with_prompt "cd /usr/local && git clone https://github.com/eclipse/eclipse.jdt.ls"
        run_with_prompt "cd eclipse.jdt.ls && JAVA_VERSION=19 JAVA_HOME=/usr/local/openjdk19 ./mvnw clean verify"
        echo
        echo "Installation complete!"
        run_with_prompt "cd /usr/home/$(logname)"
        run_with_prompt "mkdir -p .local/share/eclipse || cp install-files/eclipse-java-google-style-4-spaces.xml .local/share/eclipse"
    fi
    set_step "java-dev"
else
    echo "Skipping the 'java-dev' step since already completed."
fi
echo

if [ "$step" = "java-dev" ]; then
  echo "Beginning 'fusefs-exfat' step."
  echo "Installing fusefs-exfat for mounting exFAT formatted drives"
  run_with_prompt "pkg install fusefs-exfat"
  run_with_prompt "kldload fusefs"
  add_line_to_file_if_not_present 'fusefs_load="YES"' "/boot/loader.conf"
  reboot_freebsd_for_changes "fusefs kernel module installation"
  set_step "fusefs-exfat"
else
 echo "Skipping the 'fusefs-exfat' step since already completed."
fi

if [ "$step" = "fusefs-exfat" ]; then
  echo "Beginning 'nvim-packer' step."
  echo "Configuring 'packer' neovim plugin manager"
  run_with_prompt "git clone --depth 1 https://github.com/wbthomason/packer.nvim ~/.local/share/nvim/site/pack/packer/start/packer.nvim"
  set_step "nvim-packer"
else
  echo "Skipping the 'nvim-packer' step since already completed."
fi

if [ "$step" = "nvim-packer" ]; then
  echo "Beginning 'poudriere' step."
  echo "Installing poudriere for custom ports config and installation."
  run_with_prompt "pkg install poudriere"
  echo "!Important! Configure poudriere(8) in /usr/local/etc/poudriere.conf"
  set_step "poudriere"
else
 echo "Skipping the 'poudriere' step since already completed."
fi

if [ "$step" = "poudriere" ]; then
  echo "Beginning 'webcamd' step."
  echo "Installing webcamd for USD webcam usage."
  run_with_prompt "pkg install webcamd"
  echo 'Adding webcamd_enable="YES" to rc.conf.'
  run_with_prompt 'sysrc -f /etc/rc.conf webcamd_enable="YES"'
  echo 'Appending cuse_load="YES" to /boot/loader.conf to enable cuse kernel module'
  add_line_to_file_if_not_present 'cuse_load="YES"' "/boot/loader.conf"
  echo "Adding user $user to 'webcamd' group to allow webcam usage ..."
  run_with_prompt "pw groupmod webcamd -m $user"
  echo "Installing video4linux packages"
  run_with_prompt "pkg install v4l-utils v4l_compat"
  set_step "webcamd"
else
  echo "Skipping the 'webcamd' step since already completed."
fi
