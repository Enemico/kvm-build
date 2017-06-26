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


VM=$1
VIRSH=/usr/bin/virsh
QEMU=/usr/bin/qemu-img
POOL=default
POOL_DIR=/var/lib/libvirt/images

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

if [ -z $1 ]; then
  echo "Provide an instance name, pretty please?"
  usage
  exit 1
fi

if [ ! -f /etc/libvirt/qemu/${VM}.xml ]; then
  echo "$VM doesn't exists, as far as i can see."
  exit 1
fi

check_running () {
  $VIRSH list --name | grep -w $VM > /dev/null 2>&1
}

pool_list () {
  $VIRSH vol-list --pool $POOL
}

check_running
if [ $? -eq "0" ]; then
  echo "The requested instance $VM it's running on this hypervisor."
  echo "We will have to turn it down."
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
fi

check_running
if [ $? -eq "0" ]; then
  echo "$VM is still running, and we previously tried to destroy it. Bailing out."
  exit 1
fi

### From the instance name, extract the DISTRO name.
DISTRO=$($VIRSH list --inactive --name | grep ${VM} | cut -f1 -d ".")
echo "${VM} is using the golden image for the $DISTRO distribution."

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

echo "Here is the backing chain for ${VM} atm."
## Check the backing chain
$QEMU info --backing-chain $POOL_DIR/${VM}.qcow2


## Rebasing of the image.
#$QEMU rebase -b $POOL_DIR/$POOL/${VM}.base.img $POOL_DIR/$POOL/${VM}.qcow2
#$QEMU commit $POOL_DIR/$POOL/${VM}.qcow2

$QEMU rebase -b $POOL_DIR/${VM}.base.img $POOL_DIR/${VM}.qcow2
$QEMU commit $POOL_DIR/${VM}.qcow2


## Removing the clone image
rm -f $POOL_DIR/${VM}.qcow2

## Renaming the rebased image wuth the VM name
mv $POOL_DIR/${VM}.base.img $POOL_DIR/${VM}.qcow2
/bin/chown libvirt-qemu:kvm $POOL_DIR/${VM}.qcow2
chmod +w $POOL_DIR/${VM}.qcow2

echo "Here is the new backing chain for $VM after the consolidation (rebase ) process."

## Check the backing chain
$QEMU info --backing-chain $POOL_DIR/${VM}.qcow2

## fix permissions
chown libvirt-qemu:kvm $POOL_DIR/${VM}.qcow2
chmod 644 $POOL_DIR/${VM}.qcow2


echo "If this looks OK, then you can run: virsh start $VM"


exit 0

