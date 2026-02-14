#!/bin/sh

# FreeBSD installation install.sh
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

. ./common.sh
ensure_working_directory "/usr/home/$(logname)"
ensure_root

echo
user=$(logname)
read -p "Proceed with setup steps for user $user? " yn
case $yn in
  [Yy]* ) echo "Ok, proceeding.";;
  * ) exit;;
esac
echo

step=" "
if [ -f "./.step.txt" ]; then
  step=$(cat ./.step.txt)
  echo "Last completed step: $step"
else
  echo "Had not yet completed any steps."
fi
press_enter_to_continue

run_with_prompt "ping -c 1 pkg.freebsd.org && pkg update && pkg upgrade"

if [ "$step" = " " ]; then
  echo "Beginning 'operatorgroup' step."
  echo "Adding user $user to 'operator' group to allow shutdown/reboot without sudo ..."
  run_with_prompt "pw groupmod operator -m $user"
  echo "The 'operator' group is now: $(pw groupshow operator)"
  press_enter_to_continue
  set_step "operatorgroup"
else
  echo "Skipping the 'operatorgroup' step since already completed."
fi
echo

if [ "$step" = "operatorgroup" ]; then
  echo "Beginning 'timezone' step."
  echo "Setting timezone to UTC"
  run_with_prompt "tzsetup /usr/share/zoneinfo/UTC"
  echo "Running 'adjkerntz -a' to update kernel with UTC timezone"
  run_with_prompt "adjkerntz -a"
  set_step "timezone"
else
  echo "Skipping the 'timezone' step since already completed."
fi
echo

if [ "$step" = "timezone" ]; then
  echo "Beginning 'videogroup' step."
  echo "Adding user $user to 'video' group for GPU acceleration ..."
  run_with_prompt "pw groupmod video -m $user"
  echo "The 'video' group is now: $(pw groupshow video)"
  press_enter_to_continue
  set_step "videogroup"
else
  echo "Skipping the 'videogroup' step since already completed."
fi 
echo

if [ "$step" = "videogroup" ]; then
  echo "Beginning 'drm-kmod' step."
  echo "Installing the graphics/drm-kmod package."
  run_with_prompt "pkg install drm-kmod"
  set_step "drm-kmod"
else
  echo "Skipping the 'drm-kmod' step since already completed."
fi
echo

if [ "$step" = "drm-kmod" ]; then
  echo "Beginning 'kld_list' step."
  echo "Please confirm system uses Intel Integrated Graphics."
  echo "If your system uses a different GPU type, consult https://wiki.freebsd.org/Graphics to modify this step."
  read -p "Proceed to set kld_list+=i915kms in /etc/rc.conf? " yn
  case $yn in
    [Yy]* )
      echo "Ok, proceeding."
      run_with_prompt "sysrc -f /etc/rc.conf kld_list+=i915kms"
      set_step "kld_list"
      reboot_freebsd_for_changes "update to graphics drivers"
    ;;
    * )
      echo "Ok, skipped." && echo
      set_step "kld_list"
    ;;
  esac
else
  echo "Skipping the 'kld_list' step since already completed."
fi
echo

if [ "$step" = "kld_list" ]; then
  echo "Beginning 'console-font' step."
  echo "Setting console font to terminus-b32 in rc.conf."
  run_with_prompt 'sysrc -f /etc/rc.conf allscreens_flags="-f terminus-b32"'
  set_step "console-font"
  reboot_freebsd_for_changes "new console font"
else
  echo "Skipping the 'console-font' step since already completed."
fi
echo

if [ "$step" = "console-font" ]; then
  echo "Beginning 'xorg' step."
  run_with_prompt "pkg install xorg"
  echo "Appending 'kern.vty=vt' to /boot/loader.conf to enable vt"
  add_line_to_file_if_not_present "kern.vty=vt" "/boot/loader.conf"
  set_step "xorg"
else
  echo "Skipping the 'xorg' step since already completed."
fi
echo

if [ "$step" = "xorg" ]; then 
  echo "Beginning 'fonts' step."
  run_with_prompt "pkg install urwfonts"
  press_enter_to_continue
  run_with_prompt "pkg install freefont-ttf"
  press_enter_to_continue
  run_with_prompt "pkg install nerd-fonts"
  press_enter_to_continue
  echo 'Checking for line: Load "freetype" in /etc/X11/xorg.conf'
  if [ -f "/etc/X11/xorg.conf" ]; then
    if [ $(grep -c 'Load "freetype"' /etc/X11/xorg.conf) -ne 0 ]; then
      echo "Line was already in file, will not add it."
      echo
    else
      echo "File was found but line was not in file."
      if [ $(grep -c 'Section "Module"' /etc/X11/xorg.conf) -ne 0 ]; then
        echo 'Section "Module" was already in file. Please add the line:'
        echo
        echo '  Load "freetype"'
        echo
        echo "to the section and resume this script."
        echo
        printf "%s " "Press Enter to exit"
        read ans
        exit 0
      else
        echo 'Section "Module" was not already in file, adding the section with'
        echo -n 'Load "freetype" line'
        echo >> /etc/X11/xorg.conf
        echo 'Section "Module"' >> /etc/X11/xorg.conf
        echo '	Load "freetype"' >> /etc/X11/xorg.conf
        echo "EndSection" >> /etc/X11/xorg.conf
        echo "Finished."
      fi
    fi
  else
    echo -n "File was not found, adding section to file ... "
    echo 'Section "Module"' >> /etc/X11/xorg.conf
    echo '	Load "freetype"' >> /etc/X11/xorg.conf
    echo "EndSection" >> /etc/X11/xorg.conf
    echo "Finished."
  fi
  run_with_prompt "pkg install mkfontscale"
  if [ ! -f ".xinitrc" ]; then
    echo ".xinitrc file did not exist, will copy it from template and chown to $user:$user"
    run_with_prompt "cp configs/xorg/xinitrc-template .xinitrc && chown $user:$user .xinitrc"
  fi

  for font_dir in $(find /usr/local/share/fonts -maxdepth 1 -mindepth 1)
  do
    run_with_prompt "cd $font_dir && mkfontscale && mkfontdir && cd /usr/home/$user"
    add_line_to_file_if_not_present "xset fp+ $font_dir" ".xinitrc"
  done
  add_line_to_file_if_not_present "xset fp rehash" ".xinitrc"
  run_with_prompt "pkg install xlsfonts"
  run_with_prompt "fc-cache -f"
  set_step "fonts"
else
  echo "Skipping the 'fonts' step since already completed."
fi
echo

if [ "$step" = "fonts" ]; then
  echo "Beginning 'monospace' step."
  echo "Choose a font family from 'fc-list' for monospace"
  read -p "Enter the filename portion for monospace font family (e.g. 'roboto-mono'): " mono_filename
  indexed_mono_filename="54-$mono_filename.conf"
  new_mono_avail_filename="/usr/local/etc/fonts/conf.avail/$indexed_mono_filename"
  run_with_prompt "cp configs/freebsd/54-font-family.conf $new_mono_avail_filename"
  read -p "Enter the font family name as listed in fc-list (e.g. 'Roboto Mono'): " font_family
  echo "Editing the $new_mono_avail_filename file to point to font family $font_family:"
  run_with_prompt "sed -i '' 's/fontfamily/$font_family/g' $new_mono_avail_filename"
  echo "Symlinking $new_mono_avail_filename to be pointed to by ../conf.d/$indexed_mono_filename"
  run_with_prompt "cd /usr/local/etc/fonts/conf.d && ln -s ../conf.avail/$indexed_mono_filename $indexed_mono_filename && cd /usr/home/$user"
  echo "If symlink was successful it should appear below,"
  echo "and have higher priority (lower index) than other mono files:"
  echo
  ls -l /usr/local/etc/fonts/conf.d | grep mono
  echo
  run_with_prompt "fc-cache -f"
  echo "The monospace font is now: $(fc-match monospace)"
  echo
  set_step "monospace"
else
  echo "Skipping the 'monospace' step since already completed."
fi
echo  

if [ "$step" = "monospace" ]; then
  echo "Beginning 'configure-x-console' step."
  run_with_prompt "pkg install rxvt-unicode urxvt-font-size urxvt-perls"
  echo "Configuring shell autostart script to export urxvt as the default terminal."
  read -p "What is your shell autostart script filename (e.g. '.shrc')? " autostart_filename
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
export TERMINAL="/usr/local/bin/urxvtc"
# add local bin repo to PATH
PATH=${PATH}:/usr/local/$user/bin' "$autostart_filename"
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
  echo "Copying Xresources setup file to ~/.Xresources"
  echo "Note! Some defaults in this file may need to be adjusted."
  echo "To find the correct DPI for the file, start an X session"
  echo "with 'startx' and run 'xdpyinfo | grep -B2 resolution'"
  run_with_prompt "cp configs/xorg/Xresources .Xresources && chown $user:$user .Xresources"
  set_step "configure-x-console"
  echo
else
  echo "Skipping the 'configure-x-console' step since already completed."
fi
echo

if [ "$step" = "configure-x-console" ]; then
  echo "Beginning 'remap-left-capslock-to-ctrl' step"
  run_with_prompt "sysrc keymap=us.ctrl"
  echo 'Checking for line: Option "XKbOptions" "ctrl:nocaps" /etc/X11/xorg.conf'
  if [ -f "/etc/X11/xorg.conf" ]; then
    if [ grep -q 'Option "XKbOptions" "ctrl:nocaps"' /etc/X11/xorg.conf ]; then
      echo "Line was already in file, will not add it."
      echo
    else
      echo "File was found but line was not in file."
      run_with_prompt "echo >> /etc/X11/xorg.conf && cat configs/freebsd/90-custom-kbd.conf >> /etc/X11/xorg.conf"
    fi
  else
    echo -n "File was not found, adding section to file ... "
    run_with_prompt "cat configs/freebsd/90-custom-kbd.conf >> /etc/X11/xorg.conf"
  fi
  run_with_prompt "pkg install mkfontscale"
  set_step "remap-left-capslock-to-ctrl"
else
  echo "Skipping the 'remap-left-capslock-to-ctrl' step since already completed."
fi
echo

setup_i3_config() {
  echo
  echo -n "Setting up i3 config file with Win modkey and vim-style movement defaults ... "
  cp /usr/local/etc/i3/config .config/i3
  sed -i '' 's/# Font for window titles/set $mod Mod4\n\n# Font for window titles/g' .config/i3/config
  sed -i '' 's/Mod1/$mod/g' .config/i3/config
  sed -i '' 's/set $up l/set $up k/g' .config/i3/config
  sed -i '' 's/set $down k/set $down j/g' .config/i3/config
  sed -i '' 's/set $left j/set $left h/g' .config/i3/config
  sed -i '' 's/set $right semicolon/set $right l/g' .config/i3/config
  sed -i '' 's/exec i3-config-wizard//g' .config/i3/config
  sed -i '' 's/bindsym $mod+h split h/bindsym $mod+s split h/g' .config/i3/config
  sed -i '' 's/bindsym $mod+s layout stacking/bindsym $mod+t layout stacking/g' .config/i3/config
  echo "Note that you can set the font size for status bar and window labels"
  echo "by changing the line 'font pango:monospace 8' ."
  chown $user:$user /usr/home/$user/.config/i3/config
  echo "Succeeded."
  echo
}

if [ "$step" = "remap-left-capslock-to-ctrl" ]; then
  echo "Beginning 'i3wm' step."
  echo "Installing i3wm and dmenu."
  run_with_prompt "pkg install -y i3 i3lock i3status"
  run_with_prompt "pkg install dmenu"
  add_line_to_file_if_not_present "/usr/local/bin/i3" ".xinitrc"
  echo "The contents of .xinitrc are now:"
  echo
  cat .xinitrc
  echo
  if prompt "Setup i3 config file?"; then
    setup_i3_config
  fi
  press_enter_to_continue
  echo "i3wm and dmenu have now been installed!"
  echo "Start i3wm with 'startx' after reboot to ensure config was successful."
  set_step "i3wm"
else
  echo "Skipping the 'i3wm' step since already completed."
fi
echo

if [ "$step" = "i3wm" ]; then
  echo "Beginning 'essential-progs' step."
  run_with_prompt "pkg install rsync"
  run_with_prompt "pkg install git"
  run_with_prompt "pkg install lsof"
  run_with_prompt "pkg install ripgrep"
  run_with_prompt "pkg install neovim"
  run_with_prompt "pkg install scrot"
  run_with_prompt "pkg install npm"
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
