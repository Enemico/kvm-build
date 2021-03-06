#!/bin/bash

# set -x
DISTRO=$1
CWD="/var/lib/libvirt/images"
USER="sub"
FILENAME="/home/sub/authorized_keys"
VIRSH=$(which virsh)
SYSPREP=$(which virt-sysprep)
GUESTFISH=$(which guestfish)

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

## check if virsh command is available
which virsh
if [ $? -ne "0" ]; then
  echo "virt-clients not installed, check requirements into README"
  exit 1
fi

### the orignal installation should not be running.
$VIRSH list --name | grep -w $DISTRO.orignal > /dev/null 2>&1
if [ $? -eq "0" ]; then
  echo "We need to shutdown the original instance before we start preparing a golden image"
  echo "Please do that first. Run 'virsh shutdown' followed by the name of the instance."
  echo "For example: 'virsh shutdown debian8.original' "
  exit 1
fi

### clones using snapshots of this golden image should not run when we re/create the golden image.
$VIRSH list --name | grep -w $DISTRO > /dev/null 2>&1
if [ $? -eq "0" ]; then
  echo "We cannot overwrite the golden image of $DISTRO when snapshots of it are in use."
  echo "Please shut down all $DISTRO based domains first. These are:"
  $VIRSH list --name | grep -w $DISTRO
  echo "Run 'virsh shutdown $($VIRSH list --name | grep -w $DISTRO)' "
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

### Once we have a golden image, we don't need the original image anymore. It takes far too much space to
### keep a copy. What we still need is the original configuration file for the VM.
if [ -f $CWD/$DISTRO.golden.img ]; then
  if [ -f $CWD/$DISTRO.original.img ]; then
    echo "Deleting the original installation medium to save space."
    $VIRSH vol-delete $DISTRO.original.img default
  fi
fi


##################
### OPERATIONS ###
##################


## check if virt-sysprep command is available
which virt-sysprep
if [ $? -ne "0" ]; then
  echo "libguestfs-tools not installed, check requirements into README"
  exit 1
fi

## remove all the configuration that would cause problems when creating multiple clones
$SYSPREP \
  --enable ssh-hostkeys,udev-persistent-net,net-hwaddr,logfiles,machine-id \
  --no-selinux-relabel \
  -a $CWD/${DISTRO}.golden.img

if [ ! -f $CWD/${DISTRO}.golden.img ]; then
  echo "something went wrong in the preparation of the golden image"
  exit 1
fi

## fix SELinux
$GUESTFISH --selinux -i $CWD/${DISTRO}.golden.img <<<'sh "load_policy && restorecon -R -v /"' > /dev/null 2>&1

## at the end of the process, we test put also the golden image in read-only now
chmod u-w $CWD/$DISTRO.golden.img
# chmod u-w $CWD/$DISTRO.original.img

exit 0
