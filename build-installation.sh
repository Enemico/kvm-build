#!/bin/bash

set -x

INSTALLER=$(which virt-install)
VIRSH=$(which virsh)
VOLUME=default
BRIDGE=virbr0
DISTRO=$1
RAM=4096
DISK=12G

usage () {
  echo "usage: build [distro]"
  echo "possible distros: ubuntu18 / ubuntu16 / centos6 / centos7 / debian8 / debian9 / debian10"
  exit 1
}

### Am i Root check
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root, or preceded by sudo."
  echo "If sudo does not work, contact your system administrator."
  exit 1
fi

check_volume () {
  check_virsh
  $VIRSH vol-list --pool $VOLUME
  if [ $? -eq "0" ]; then
    echo "Volume $VOLUME exists"
  fi
}

check_virsh () {
  which virsh
  if [ $? -ne "0" ]; then
    echo "virt-clients not installed, check requirements into README"
    exit 1
  fi
}

check_existing () {
  check_virsh
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
  --cpu=host \
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
    PRESEED='./files/ks/centos_6_x86_64/ks.cfg'
    EXTRA='acpi=on console=tty0 console=ttyS0,115200 ks=file:/ks.cfg'
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

### centos8
  -c8 | centos8 | c8)
    LOCATION='http://mirror.centos.org/centos/8/BaseOS/x86_64/os/'
    PRESEED='./files/ks/centos_8_x86_64/ks.cfg'
    EXTRA='acpi=on console=tty0 console=ttyS0,115200 ks=file:/ks.cfg'
    OS='rhel8.0'
    create_image
    create_instance
  ;;

### debian 8
  -d8 | debian8 | d8)
    LOCATION='http://ftp.us.debian.org/debian/dists/jessie/main/installer-amd64/'
    PRESEED='./files/ks/debian_8_amd64/preseed.cfg'
    EXTRA='acpi=on auto=true console tty0 console=ttyS0,115200n8 serial ks=file:/preseed.cfg'
    OS='debian8'
    create_image
    create_instance
  ;;

### debian 9
  -d9 | debian9 | d9)
    LOCATION='http://ftp.us.debian.org/debian/dists/stretch/main/installer-amd64/'
    PRESEED='./files/ks/debian_9_amd64/preseed.cfg'
    EXTRA='acpi=on auto=true console tty0 console=ttyS0,115200n8 serial ks=file:/preseed.cfg'
    OS='debian9'
    create_image
    create_instance
  ;;

### debian 10
  -d10 | debian10 | d10)
    LOCATION='http://ftp.no.debian.org/debian/dists/buster/main/installer-amd64/'
    PRESEED='./files/ks/debian_10_amd64/preseed.cfg'
    EXTRA='acpi=on auto=true console tty0 console=ttyS0,115200n8 serial ks=file:/preseed.cfg'
    OS='debian9'
    create_image
    create_instance
  ;;
### ubuntu 14
  -u14 | ubuntu14 | u14)
    LOCATION='http://no.archive.ubuntu.com/ubuntu/dists/trusty/main/installer-amd64/'
    PRESEED='./files/ks/ubuntu_14_04_amd64/preseed.cfg'
    OS='ubuntu14.04'
    EXTRA='acpi=on auto=true console=tty0 console=ttyS0,115200n8 serial ks=file:/preseed.cfg'
    echo "WARNING, Ubuntu 14.04 is EOL, no security updates from April 2019."
    create_image
    create_instance
  ;;

### ubuntu 16
  -u16 | ubuntu16 | u16)
    LOCATION='http://no.archive.ubuntu.com/ubuntu/dists/xenial/main/installer-amd64/'
    PRESEED='./files/ks/ubuntu_16_04_amd64/preseed.cfg'
    OS='ubuntu16.04'
    EXTRA='acpi=on auto=true console tty0 console=ttyS0,115200n8 serial ks=file:/preseed.cfg'
    create_image
    create_instance
  ;;

### ubuntu 18
  -u18 | ubuntu18 | u18)
    LOCATION='http://no.archive.ubuntu.com/ubuntu/dists/bionic/main/installer-amd64/'
    PRESEED='./files/ks/ubuntu_18_04_amd64/preseed.cfg'
    OS='ubuntu18.04'
    EXTRA='acpi=on auto=true console tty0 console=ttyS0,115200n8 serial ks=file:/preseed.cfg'
    create_image
    create_instance
  ;;

### ubuntu 20
  -u20 | ubuntu20 | u20)
    LOCATION='http://no.archive.ubuntu.com/ubuntu/dists/focal/main/installer-amd64/'
    PRESEED='./files/ks/ubuntu_20_04_amd64/preseed.cfg'
    OS='ubuntu20.04'
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
