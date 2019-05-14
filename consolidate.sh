#!/bin/bash

VM=$1
VIRSH=$(which virsh)
QEMU=$(which qemu-img)
POOL=default
POOL_DIR=/var/lib/libvirt/images
RELEASE=$(which lsb_release)
DISTRO=$($RELEASE -s -i)

usage () {
  echo "This command consolidates the storage of a previously created clone."
  echo "It truns off the vm (if running), and then merges a copy "
  echo "of the golden image with the snapshot used by the clone, to obtain"
  echo "a standalone image for the affected vm."
  echo "Usage: $0 [instancename]"
}

### Am i Root check
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root, or preceded by sudo."
  echo "If sudo does not work, contact your system administrator."
  exit 1
fi

### check if virsh command is available
which virsh
if [ $? -ne "0" ]; then
  echo "virt-clients not installed, check requirements into README"
  exit 1
fi

### check if qemu-img command is available
which qemu-img
if [ $? -ne "0" ]; then
  echo "qemu-utils not installed, check requirements into README"
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

if [ -z $RELEASE ]; then
  echo "You need to install lsb_release for your distribution"
  exit 1
fi

if [ $DISTRO = "Ubuntu" ]; then
  PERMS="libvirt-qemu:kvm"
elif [ $DISTRO = "CentOS" ]; then
  PERMS="root:root"
else
  echo "For now i can run on Ubuntu and Centos"
  echo "This is not the case, so i bail out, sorry."
fi

check_running () {
  $VIRSH list --name | grep -w $VM > /dev/null 2>&1
}

pool_list () {
  $VIRSH vol-list --pool $POOL
}

## Check the backing chain
check_backing () {
  $QEMU info --backing-chain $POOL_DIR/${VM}.qcow2 | grep backing
}

## print the backing chain
print_backing () {
  $QEMU info --backing-chain $POOL_DIR/${VM}.qcow2
}

## If there is no backing-chain, then we don't consolidate
check_backing
if [ $? -eq "1" ]; then
  echo "$VM has its own, monolithic disk and does not need consolidating"
  echo "Bailing out."
  exit 1
fi

check_running
if [ $? -eq "0" ]; then
  echo "INFO: the requested instance $VM is running on this hypervisor."
  echo "We will have to turn it down."
  echo ""
  $VIRSH shutdown ${VM}
  sleep 10
  check_running
  if [ $? -eq "0" ]; then
    echo "$VM is still running, i will terminate it now."
    $VIRSH destroy ${VM}
    check_running
    if [ $? -eq "0" ]; then
      echo "$VM is still alive after destroy, something is fishy..."
      echo "Bailing out"
      exit 1
    fi
  else
    echo "The domain ${VM} has been shutdown, continuing..."
  fi
else
  echo "the requested instance $VM it's not running, good."
  echo "Continuing..."
  echo ""
fi

check_running
if [ $? -eq "0" ]; then
  echo "$VM is still running, and we previously tried to destroy it. Bailing out."
  exit 1
fi

### From the instance name, extract the DISTRO name.
DISTRO=$($VIRSH list --inactive --name | grep ${VM} | cut -f1 -d ".")
echo "${VM} is using the golden image for the $DISTRO distribution."
echo ""

### Make a copy of the golden image of the corresponding distribution.
pool_list | grep $DISTRO.golden.img > /dev/null 2>&1
if [ $? -ne "0" ]; then
  echo "Uhm, something is wrong, i can't find the corresponding golden image, for some reason."
  echo "Bailing out."
  exit 1
fi

echo "Copying the golden image to a temporary file."
$VIRSH vol-clone --pool $POOL $DISTRO.golden.img ${VM}.base.img
pool_list | grep ${VM}.base.img
if [ $? -ne "0" ]; then
  echo "Something went wrong with the cloning of the golden image."
  echo "Bailing out."
  exit 1
fi

echo ""
echo "Here is the backing chain for ${VM} atm:"
echo ""
print_backing

$QEMU rebase -b $POOL_DIR/${VM}.base.img $POOL_DIR/${VM}.qcow2
$QEMU commit $POOL_DIR/${VM}.qcow2

## Removing the clone image
rm -f $POOL_DIR/${VM}.qcow2

## Renaming the rebased image wuth the VM name
mv $POOL_DIR/${VM}.base.img $POOL_DIR/${VM}.qcow2
/bin/chown $PERMS $POOL_DIR/${VM}.qcow2
chmod +w $POOL_DIR/${VM}.qcow2

## Remove the reference to the base image that did not disappear when moving it physically
$VIRSH vol-delete ${VM}.base.img --pool $POOL

echo ""
echo "Here is the new backing chain for $VM after the consolidation (rebase ) process:"
echo ""

print_backing

## fix permissions
chown $PERMS $POOL_DIR/${VM}.qcow2
chmod 644 $POOL_DIR/${VM}.qcow2

echo ""
echo "Consolidated. Can be started with 'virsh start $VM'"


exit 0

