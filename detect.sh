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

# set -x

VM=$1
VIRSH=/usr/bin/virsh
MAC=`grep -ir "mac address" /etc/libvirt/qemu/${VM}.xml | awk -F"'" '{print $2}'`
BRIDGE=`grep -ir "source bridge" /etc/libvirt/qemu/${VM}.xml | awk -F"'" '{print $2}'`

usage () {
  echo "Usage: $0 [instancename]"
}

### Am i Root check
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root, or preceded by sudo."
  echo "If sudo does not work, contact your system administrator."
  exit 1
fi

### check if the command was ran with an argument
if [ -z $1 ]; then
  echo "Provide an instance name, pretty please?"
  usage
  exit 1
fi

### check if the VM actually exists ( has a corresponding configuration file )
if [ ! -f /etc/libvirt/qemu/${VM}.xml ]; then
  echo "$VM doesn't exists, as far as i can see."
  exit 1
fi

### check if the VM is actually running
check_existing () {
  $VIRSH list --name | grep -w $VM > /dev/null 2>&1
}

### This check worked only on some specific machines, should be adjusted to a more
### general use.
if [ -f /var/lib/libvirt/dnsmasq/default.leases ]; then
  IP=`cat /var/lib/libvirt/dnsmasq/default.leases | grep -i $MAC | awk '{print $3}'`
  check_existing
  if [ $? -ne "0" ]; then
    echo "the requested instance $VM exists on this hypervisor, but doesn't seem to be running at the moment."
    exit 1
  fi
fi

### count how many bridges we have
grep -ir "source bridge" /etc/libvirt/qemu/${VM}.xml | awk -F"'" '{print $2}' > /tmp/bridges
BRIDGEAMOUNT=$(cat /tmp/bridges | wc -l)
echo "We have $BRIDGEAMOUNT ethernet bridges on $VM"

### dump the mac addresses to a file in the same fashion as we just did for bridges
grep -ir "mac address" /etc/libvirt/qemu/${VM}.xml | awk -F"'" '{print $2}' > /tmp/macs

### if we have a single bridge, detect the ip on that bridge
if [ $BRIDGEAMOUNT -lt "2" ]; then
  ### Use arp to find the ip address 
  if [ -z "$IP" ]; then
    arp -a -i $BRIDGE | grep -i $MAC > /tmp/arp.txt
    IP=`grep -oP '\(\K[^)]+' /tmp/arp.txt`
  fi
  ### Echo the result
  if [ ! -z "$IP" ]; then
    echo "$IP is assigned to $VM"
  else
    echo "it wasn't possible to detect the ip address for $VM. Uhmmm."
  exit 1
  fi
fi 

### exit if we have a multibridge machine
if [ $BRIDGEAMOUNT -gt "1" ]; then
  echo "we have more than 1 bridge, so we have more than one IP address, at the moment i am too stupid to do this."
  echo "Sorry."
  exit 1
fi

exit 0
