#!/bin/bash

### Am i Root check
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root, or preceded by sudo."
  echo "If sudo does not work, contact your system administrator."
  exit 1
fi

apt install vim console-setup systemd-resolved gnome-tweaks
dpkg-reconfigure openssh-server
