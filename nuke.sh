#!/bin/bash
#set -x

VM=$1
VIRSH=/usr/bin/virsh
CWD="/var/lib/libvirt/images"

check_original () {
  echo $VM > /tmp/name
  if [ `cat /tmp/name | grep -E 'original|golden'` ]; then
    echo "WARNING, you are asking me to nuke an original or golden image" 
    read -rep $'Are you sure?\n'
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Aborted"
      exit 1
    fi
  fi
}

check_existing () {
  $VIRSH list --all --name | grep -w $VM > /dev/null 2>&1
}

check_running () {
  $VIRSH list --name | grep -w $VM > /dev/null 2>&1
}

check_original

check_existing
if [ $? -ne "0" ]; then
  echo "No domain found named $VM found. Bailing out."
  exit 1
fi

check_running
if [ $? -eq "0" ]; then
  echo "Destroying $VM"
  $VIRSH destroy $VM
fi

check_running
if [ $? -eq "1" ]; then
  if [ -f /etc/libvirt/qemu/$VM.xml ]; then
    echo "Removing kvm configuration file..."
    $VIRSH undefine $1
  else
    echo "No configuration file for $VM"
  fi
  if [ -f $CWD/$VM.img ]; then
    echo "Nuking $VM.img..."
    $VIRSH vol-delete $VM.img --pool=default
  fi
  if [ -f $CWD/$VM.qcow2 ]; then
    echo "Nuking $VM.qcow2..."
    $VIRSH vol-delete $VM.qcow2 --pool=default
  fi
else
  echo "can't determine if $VM is running, got $? exit"
  exit 1
fi

exit 0
