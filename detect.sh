#!/bin/bash

VM=$1
VIRSH=/usr/bin/virsh
MAC=`grep -ir "mac address" /etc/libvirt/qemu/${VM}.xml | awk -F"'" '{print $2}'`

usage () {
  echo "Usage: $0 [instancename]"
}

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
