#!/bin/sh

read -p "Enter wireless network SSID: " ssid
read -p "Enter wireless network password: " passwd

wpa_passphrase $ssid $passwd >> /etc/wpa_supplicant/wpa_supplicant.conf

echo "Running 'ln -s /etc/sv/wpa_supplicant /var/service' to enable wpa_supplicant service"
run_with_prompt 'ln -s /etc/sv/wpa_supplicant /var/service'
