#!/bin/bash

set -x

INSTALLER=/usr/bin/virt-install
VIRSH=/usr/bin/virsh
VOLUME=default
BRIDGE=virbr0
DISTRO=$1
RAM=4096
DISK=12G

usage () {
  echo "usage: build [distro]"
  echo "possible distros: centos6 / centos7 / debian8"
  exit 1
}

check_volume () {
  $VIRSH vol-list --pool $VOLUME
  if [ $? -eq "0" ]; then
    echo "Volume $VOLUME exists"
  fi
}
check_existing () {
  $VIRSH list --all --name | grep -w $DISTRO.original > /dev/null 2>&1
    if [ $? -eq "0" ]; then
      echo "We already have a $DISTRO.original image in stock."
      exit 1
    fi
}

## we create a 12G golden image in case we are going to need more space in some cases
create_image () {
  check_existing
  $VIRSH vol-create-as $VOLUME $DISTRO.original.img $DISK --format qcow2
}

create_instance () {
  $INSTALLER --debug --name $DISTRO.original \
  --ram=$RAM \
  --graphics none \
  --console pty,target_type=serial \
  --bridge $BRIDGE \
  --disk vol=$VOLUME/$DISTRO.original.img \
  --os-variant $OS \
  --location "$LOCATION" \
  --initrd-inject $PRESEED \
  --extra-args="$EXTRA"
}

case "$1" in
### help
  -h | help | --help)
    usage
  ;;
### centos6
  -c6 | centos6 | c6)
    LOCATION='http://mirror.centos.org/centos/6/os/x86_64'
    EXTRA='acpi=on console=tty0 console=ttyS0,115200 ks=file:./files/ks/centos_6_x86_64/anaconda-ks.cfg'
    OS='rhel6.6'
    create_image
    create_instance
  ;;

### centos7
  -c7 | centos7 | c7)
    LOCATION='http://mirror.centos.org/centos/7/os/x86_64'
    PRESEED='./files/ks/centos_7_x86_64/ks.cfg'
    EXTRA='acpi=on console=tty0 console=ttyS0,115200 ks=file:/ks.cfg'
    OS='rhel7.0'
    create_image
    create_instance
  ;;

### debian 8
  -d8 | debian8 | d8)
    LOCATION='http://ftp.us.debian.org/debian/dists/jessie/main/installer-amd64/'
    PRESEED='./files/ks/debian_8_amd64/preseed_golden.cfg'
    EXTRA='acpi=on auto=true console tty0 console=ttyS0,115200n8 serial' 
    OS='debian8'
    create_image
    create_instance
  ;;

### ubuntu 16
  -u16 | ubuntu16 | u16)
    LOCATION='http://no.archive.ubuntu.com/ubuntu/dists/xenial/main/installer-amd64/'
    PRESEED='preseed.cfg'
    OS='ubuntu16.04'
    EXTRA='acpi=on auto=true console tty0 console=ttyS0,115200n8 serial ks=file:/preseed.cfg'
    create_image
    create_instance
  ;;

### otherwise, we show usage
  *)
    usage
    exit 0
  ;;
esac
