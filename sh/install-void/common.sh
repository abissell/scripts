#!/bin/sh

. scripts/sh/common.sh

reboot_void_for_changes() {
  reboot_for_changes "$1" 'sudo shutdown -r now'
}
