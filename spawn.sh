#!/bin/bash

#set -x
VIRSH=$(which virsh)
VIRTCLONE=$(which virt-clone)
GUESTFISH=$(which guestfish)
VIRTCOPY=$(which virt-copy-in)
DISTRO=$1
VM=$2
CWD="/var/lib/libvirt/images"

### Am i Root check
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root, or preceded by sudo."
  echo "If sudo does not work, contact your system administrator."
  exit 1
fi

## Check for virsh command
which virsh
if [ $? -ne "0" ]; then
  echo "virt-clients not installed, check requirements into README"
  exit 1
fi

usage () {
  echo "usage: $0 [distro] [instance name]"
  echo "possible distros: debian12 / debian-graphics / debian13 / debian13-grphics / ubuntu20"
  exit 1
}

### check the distro ( first ) argument
case "$1" in
### help
  -h | help | --help)
    usage
  ;;

### debian12
  debian12)
    echo "Debian 12 (bookworm) selected"
  ;;

### debian12 + graphics
  debian-graphics)
    echo "Debian 12 (bookworm) with graphics selected"
  ;;

### debian13
  debian13)
    echo "Debian 13 (trixie) selected"
  ;;

### debian13 + graphics
  debian13-graphics)
    echo "Debian 13 (trixie) with graphics selected"
  ;;

### ubuntu20
  ubuntu20)
    echo "Ubuntu 20.04 (focal) selected"
  ;;

### otherwise, we show usage
  *)
    usage
    exit 0
  ;;
esac

if [ -z "$2" ]; then
  echo "you must provide an instance name"
  usage
  exit 1
elif [ "x$2" = x ]; then
  echo "empty string on instance name"
  exit 1
fi

check_exitcode () {
  if [ $? -ne "0" ]; then
    echo "WARN $? exitcode"
  fi
}

### check the instance ( second ) argument
### we want to make sure that the inputs are valid when it comes to distro and name
### the instance name must be provided and alphanumeric
check_aln () {
  echo $VM | egrep -q "\W"
}

check_aln
if [ $? -eq "0" ]; then
  echo "We only admit alphanumerical named guests in this establishment, sorry."
  exit 1
fi

check_existing () {
  $VIRSH list --name | grep -w $DISTRO.$VM > /dev/null 2>&1
}

## check if we are trying to create a machine that already exists and is running (!)
## for example , as a consequence of a typo
check_existing
if [ $? -eq "0" ]; then
  echo "an instance called $DISTRO.$VM already exists and is running. Bailing out."
  exit 1
fi

## check if we are not risking to overwrite some important image
# FIX: replaced curly/smart quotes with straight quotes in both comparisons
if [ "$VM" = "original" ]; then
  echo "Sorry, 'original' is a bad name here."
  exit 1
fi

if [ "$VM" = "golden" ]; then
  echo "Sorry, 'golden' is a bad name here."
  exit 1
fi

## check if we have the golden image

if [ ! -f $CWD/${DISTRO}.golden.img ]; then
  echo "Sorry, we don't have a golden image ready for ${DISTRO}."
  echo "Use ./build-installation.sh ${DISTRO} first, then"
  echo "run ./prepare-golden.sh ${DISTRO}. Then retry with this command."
  exit 1
fi

## create a clone, referencing only to the copy
qemu-img create -b $CWD/${DISTRO}.golden.img -F qcow2 -f qcow2 $CWD/${DISTRO}.${VM}.qcow2
check_exitcode

### clone the configuration file for kvm
$VIRSH dumpxml $DISTRO.original > /tmp/$DISTRO.original.xml
check_exitcode

### change the cache type from none to unsafe
# sed -i 's/none/unsafe/g' /tmp/$DISTRO.original.xml

# clone the configuration file using the original distro one, changing the image reference to point at the prepared image
$VIRTCLONE --original-xml /tmp/$DISTRO.original.xml --name ${DISTRO}.${VM} --preserve-data --file $CWD/${DISTRO}.${VM}.qcow2
check_exitcode

# start the machine!
$VIRSH start ${DISTRO}.${VM}
check_exitcode

extract_address () {
  # extract the mac address from the configuration file
  MAC=`grep -ir "mac address" /etc/libvirt/qemu/${DISTRO}.${VM}.xml | awk -F"'" '{print $2}'`
  ### grep for the mac address in the dhcp leases if any, else use arp to find it
  if [ -f /var/lib/libvirt/dnsmasq/default.leases ]; then
    IP=`cat /var/lib/libvirt/dnsmasq/default.leases | grep -i $MAC | awk '{print $3}'`
  else
    arp -a -i virbr0 | grep -i $MAC > /tmp/arp.txt
    IP=`grep -oP '\(\K[^)]+' /tmp/arp.txt`
  fi
}

extract_address
if [ -z "$IP" ]; then
  echo "Waiting for the instance to boot..."
  sleep 40
  extract_address  # FIX: re-run after sleep so IP can be populated
fi

# FIX: guard the final echo — IP may still be empty if the VM is slow to get a lease
if [ -z "$IP" ]; then
  echo "WARNING: Could not determine IP address for ${DISTRO}.${VM}. The instance may still be booting."
  echo "Try running ./detect.sh ${DISTRO}.${VM} once it has fully started."
else
  echo "$IP has been assigned to ${DISTRO}.${VM} by DHCP"
fi
