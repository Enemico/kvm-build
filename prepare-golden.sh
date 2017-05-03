#!/bin/bash

# set -x
DISTRO=$1
CWD="/var/lib/libvirt/images"
USER="sub"
FILENAME="/home/sub/authorized_keys"
VIRSH=/usr/bin/virsh

usage () {
  echo "usage: $0 [distro]"
}

if [ -z $1 ]; then
  usage
  exit 1
fi

#####################
### SANITY CHECKS ###
#####################

### Am i Root check
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root, or preceded by sudo."
  echo "If sudo does not work, contact your system administrator."
  exit 1
fi

### the orignal installation should not be running.
$VIRSH list --name | grep -w $DISTRO.orignal > /dev/null 2>&1
if [ $? -eq "0" ]; then
  echo "We need to shutdown the original instance before we start preparing a golden image"
  echo "Please do that first."
  exit 1
fi

### clones using snapshots of this golden image should not run when we re/create the golden image.
$VIRSH list --name | grep -w $DISTRO > /dev/null 2>&1
if [ $? -eq "0" ]; then
  echo "We cannot overwrite the golden image of $DISTRO when snapshots of it are in use."
  echo "Please shut down all $DISTRO based domains first. These are:"
  $VIRSH list --name | grep -w $DISTRO
  exit 1
fi

### the same applies if snapshots of the golden image already exist, to overwrite the the image they
### are referring to does not sound like a good idea.
$VIRSH list --name --all | grep -w $DISTRO | grep -v $DISTRO.original > /dev/null 2>&1
if [ $? -eq "0" ]; then
  echo "We cannot overwrite the golden image of $DISTRO when snapshots of it exist."
  echo "Please nuke all $DISTRO based domains first. These are:"
  $VIRSH list --name --all | grep -w $DISTRO | grep -v $DISTRO.original
  exit 1
fi

### The original installation image should exist.
### Then we can copy it over. 
if [ -f $CWD/$DISTRO.original.img ]; then
  cp $CWD/$DISTRO.original.img $CWD/${DISTRO}.golden.img
else
  echo "I cannot find the base installation image for $DISTRO"
  exit 1
fi

##################
### OPERATIONS ###
##################

### make sure the original image is read-only
chmod u-w $CWD/$DISTRO.original.img

## remove all the configuration that would cause problems when creating multiple clones
/usr/bin/virt-sysprep \
  --enable ssh-hostkeys,udev-persistent-net,net-hwaddr,logfiles,machine-id \
  --no-selinux-relabel \
  -a $CWD/${DISTRO}.golden.img

if [ ! -f $CWD/${DISTRO}.golden.img ]; then
  echo "something went wrong in the preparation of the golden image"
  exit 1
fi

## fix SELinux
/usr/bin/guestfish --selinux -i $CWD/${DISTRO}.golden.img <<<'sh "load_policy && restorecon -R -v /"' > /dev/null 2>&1

## at the end of the process, we test put also the golden image in read-only now
chmod u-w $CWD/$DISTRO.golden.img

exit 0
