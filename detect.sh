#!/bin/bash

##    Copyright [2016] [Cfengine AS]
##
##    Licensed under the Apache License, Version 2.0 (the "License");
##    you may not use this file except in compliance with the License.
##    You may obtain a copy of the License at
##
##        http://www.apache.org/licenses/LICENSE-2.0
##
##    Unless required by applicable law or agreed to in writing, software
##    distributed under the License is distributed on an "AS IS" BASIS,
##    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##    See the License for the specific language governing permissions and
##    limitations under the License.
##



VM=$1
VIRSH=/usr/bin/virsh
MAC=`grep -ir "mac address" /etc/libvirt/qemu/${VM}.xml | awk -F"'" '{print $2}'`

usage () {
  echo "Usage: $0 [instancename]"
}

### Am i Root check
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root, or preceded by sudo."
  echo "If sudo does not work, contact your system administrator."
  exit 1
fi

if [ -z $1 ]; then
  echo "Provide an instance name, pretty please?"
  usage
  exit 1
fi

if [ ! -f /etc/libvirt/qemu/${VM}.xml ]; then
  echo "$VM doesn't exists, as far as i can see."
  exit 1
fi

check_existing () {
  $VIRSH list --name | grep -w $VM > /dev/null 2>&1
}


if [ -f /var/lib/libvirt/dnsmasq/default.leases ]; then
  IP=`cat /var/lib/libvirt/dnsmasq/default.leases | grep -i $MAC | awk '{print $3}'`
  check_existing
  if [ $? -ne "0" ]; then
    echo "the requested instance $VM exists on this hypervisor, but doesn't seem to be running at the moment."
    exit 1
  fi
fi
### grep for the mac address in the dhcp leases if any, else use arp to find it
  if [ -z "$IP" ]; then
    arp -a -i virbr0 | grep -i $MAC > /tmp/arp.txt
    IP=`grep -oP '\(\K[^)]+' /tmp/arp.txt`
  fi

if [ ! -z "$IP" ]; then
  echo "$IP is assigned to $VM"
else
  echo "it wasn't possible to detect the ip address for $VM. Uhmmm."
  exit 1
fi

exit 0
