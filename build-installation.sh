#!/bin/bash

set -x

INSTALLER=$(which virt-install)
VIRSH=$(which virsh)
VOLUME=default
BRIDGE=virbr0
DISTRO=$1
RAM=8192
DISK=20G

usage () {
  echo "usage: build [distro]"
  echo "possible distros: ubuntu20 / debian12 / debian-graphics"
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

check_pool () {
  check_virsh
  $VIRSH pool-info --pool $VOLUME
  if [ $? -ne "0" ]; then
    echo "default pool does not exists, please create it and start it"
    exit 1
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
  --vcpus 4 \
  --ram=$RAM \
  --graphics $GRAPHICS \
  --console pty,target_type=serial \
  --bridge $BRIDGE \
  --disk vol=$VOLUME/$DISTRO.original.img \
  --os-variant $OS \
  --location "$LOCATION" \
  --initrd-inject="$PRESEED" \
  --extra-args="$EXTRA"
}

case "$1" in
### help
  -h | help | --help)
    usage
  ;;

### debian 12
  debian12)
    LOCATION='http://ftp.no.debian.org/debian/dists/bookworm/main/installer-amd64/'
    PRESEED='./files/ks/debian_12_amd64/preseed.cfg'
    EXTRA='acpi=on auto=true console tty0 console=ttyS0,115200n8 serial ks=file:/preseed.cfg'
    OS='debian12'
    GRAPHICS='none'
    create_image
    create_instance
  ;;

### debian 12 with graphics
  debian-graphics)
    LOCATION='http://ftp.no.debian.org/debian/dists/bookworm/main/installer-amd64/'
    PRESEED='./files/ks/debian_12_amd64_g/preseed.cfg'
    EXTRA='acpi=on auto=true ks=file:/preseed.cfg'
    OS='debian12'
    GRAPHICS='vnc'
    create_image
    create_instance
  ;;

### ubuntu 20
  ubuntu20)
    LOCATION='http://no.archive.ubuntu.com/ubuntu/dists/focal/main/installer-amd64/'
    PRESEED='./files/ks/ubuntu_20_04_amd64/preseed.cfg'
    OS='ubuntu20.04'
    GRAPHICS='none'
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
