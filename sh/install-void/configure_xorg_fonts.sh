#!/bin/sh

. scripts-y/sh/install-void/common.sh

echo 'Checking for line: Load "freetype" in /etc/X11/xorg.conf'
if [ -f "/etc/X11/xorg.conf" ]; then
  if [ $(grep -c 'Load "freetype"' /etc/X11/xorg.conf) -ne 0 ]; then
    echo 'Line was already in file, will not add it.'
    echo
  else
    echo 'File was found but line was not in file.'
    if [ $(grep -c 'Section "Module"' /etc/X11/xorg.conf) -ne 0 ]; then
      echo 'Section "Module" was already in file. Please add the line:'
      echo
      echo '  Load "freetype"'
      echo
      echo 'to the section and resume this script.'
      echo
      printf "%s " "Press Enter to exit"
      read ans
      exit 0
    else
      echo 'Section "Module" was not already in file, adding the section with'
      echo -n 'Load "freetype" line'
      echo '' | sudo tee -a /etc/X11/xorg.conf
      echo 'Section "Module"' | sudo tee -a /etc/X11/xorg.conf
      echo '	Load "freetype"' | sudo tee -a /etc/X11/xorg.conf
      echo 'EndSection' | sudo tee -a /etc/X11/xorg.conf
      echo 'Finished.'
    fi
  fi
else
  echo -n 'File was not found, adding section to file ... '
  sudo touch /etc/X11/xorg.conf
  echo 'Section "Module"' | sudo tee -a /etc/X11/xorg.conf
  echo '	Load "freetype"' | sudo tee -a /etc/X11/xorg.conf
  echo 'EndSection' | sudo tee -a /etc/X11/xorg.conf
  echo 'Finished.'
fi

if [ ! -f '.xinitrc' ]; then
  echo '.xinitrc file did not exist, will copy it from template'
  run_with_prompt 'cp configs/xorg/xinitrc-template .xinitrc'
fi

# setup_font_dir() {
#   for font_dir in $(find $1 -maxdepth 1 -mindepth 1); do
#     run_with_prompt "cd $font_dir && sudo mkfontscale && sudo mkfontdir && cd $HOME"
#     add_line_to_file_if_not_present "xset fp+ $font_dir" '.xinitrc'
#   done
# }

for font_dir in $(find /usr/share/fonts -maxdepth 1 -mindepth 1); do
  run_with_prompt "cd $font_dir && sudo mkfontscale && sudo mkfontdir && cd $HOME"
  add_line_to_file_if_not_present "xset fp+ $font_dir" '.xinitrc'
done

for font_dir in $(find .fonts -maxdepth 1 -mindepth 1); do
  run_with_prompt "cd $font_dir && sudo mkfontscale && sudo mkfontdir && cd $HOME"
  add_line_to_file_if_not_present "xset fp+ $font_dir" '.xinitrc'
done

# setup_font_dir /usr/share/fonts
# setup_font_dir "$HOME/.fonts"

add_line_to_file_if_not_present 'xset fp rehash' '.xinitrc'
run_with_prompt 'sudo xbps-install xlsfonts'
run_with_prompt 'fc-cache -fv'

echo "Choose a font family from 'fc-list' for monospace"
read -p "Enter the filename portion for monospace font family (e.g. 'courier-code'): " mono_filename
indexed_mono_filename="54-$mono_filename.conf"
new_mono_avail_filename="/etc/fonts/conf.avail/$indexed_mono_filename"
run_with_prompt "sudo cp configs/freebsd/54-font-family.conf $new_mono_avail_filename"
read -p "Enter the font family name as listed in fc-list (e.g. 'Courier Code'): " font_family
echo "Editing the $new_mono_avail_filename file to point to font family $font_family:"
run_with_prompt "sudo sed -i 's/fontfamily/$font_family/g' $new_mono_avail_filename"
echo "Symlinking $new_mono_avail_filename to be pointed to by ../conf.d/$indexed_mono_filename"
run_with_prompt "cd /etc/fonts/conf.d && sudo ln -s ../conf.avail/$indexed_mono_filename $indexed_mono_filename && cd $HOME"
echo "If symlink was successful it should appear below,"
echo "and have higher priority (lower index) than other mono files:"
echo
ls -l /etc/fonts/conf.d | grep mono
echo
run_with_prompt 'fc-cache -fv'
echo "The monospace font is now: $(fc-match monospace)"
echo
