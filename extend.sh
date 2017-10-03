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
EXTENT=$2
VIRSH=$(which virsh)
QEMU=$(which qemu-img)
POOL=default
POOL_DIR=/var/lib/libvirt/images
RESIZE=$(which virt-resize)
RELEASE=$(which lsb_release)
DISTRO=$($RELEASE -s -i)
FILESYSTEM=$(which virt-filesystems)

usage () {
  echo ""
  echo "Usage: $0 <vm-name> <desired-size>"
  echo ""
  echo "This command extends the disk size of an existing virtual machine to a target size."
  echo "WARN: this EXPANDS a machine disk size, does NOT work for shrinking."
  echo "If the machine disk is using a backing fie, then the disk will be consolidated first,"
  echo "then the script will proceed with the extension."
  echo ""
  echo "You should specify the desired size in G or M, for example"
  echo "$0 ubuntu16.test 30G"
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

if [ -z $2 ]; then
  echo "Provide an amount in Gb you whish to add to the specified VM"
  usage
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
  echo "INFO: the requested instance $VM is running on this hypervisor."
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

## Check the backing chain
check_backing () {
  $QEMU info --backing-chain $POOL_DIR/${VM}.qcow2 | grep backing
}

## If there is a backing-chain, then we consolidate
check_backing
if [ $? -eq "0" ]; then
  ./consolidate.sh $VM
  echo "But we are to enlarge the disk size, so we continue"
fi

## determine the size of the existing disk
DISK_SIZE=$($QEMU info --backing-chain $POOL_DIR/${VM}.qcow2 | grep disk | cut -f 3 -d " ")

## determine if the existing disk contains a LVM structure
check_lvm () {
  $FILESYSTEM --long --csv -a $POOL_DIR/${VM}.qcow2 --volume-groups | grep -v Name
}

## resize the original disk on top of the desired end size
resize_partition () {
  ## create a disk with the desired output size
    $QEMU create -f qcow2 -o preallocation=metadata $POOL_DIR/${VM}-target.qcow2 "$EXTENT"

    ## resize the original disk on top of the desired end size
    echo "extending filesystem assigned to lmv ($TARGET) on $VM to $EXTENT of disk"
    $RESIZE --expand $TARGET $POOL_DIR/${VM}.qcow2 $POOL_DIR/${VM}-target.qcow2

    ## clean up this shit
    rm -rf $POOL_DIR/${VM}.qcow2
    mv $POOL_DIR/${VM}-target.qcow2 $POOL_DIR/${VM}.qcow2
    chown $PERMS $POOL_DIR/${VM}.qcow2
    chmod 644 $POOL_DIR/${VM}.qcow2

    ## refresh the pool
    $VIRSH pool-refresh $POOL 
}




## expand filesystem accordingly
check_lvm
  if [ $? -eq "0" ]; then

    ### LVM EXTENDING ###
    echo "Volume is using LVM"

    ## extract the target for expand (onliner tailored for LVM)
    TARGET=$($FILESYSTEM --long --csv -a $POOL_DIR/${VM}.qcow2 --volume-groups | grep -v Name | cut -f 4 -d ",")

    resize_partition

  elif [ $? -eq "1" ]; then
    echo "Volume is not using LVM"

    ## extract the target for expand (onliner tailored for non LVM)
    TARGET=$($FILESYSTEM --long --csv -a $POOL_DIR/${VM}.qcow2 | grep -v Name | cut -f 1 -d ",")

    resize_partition

  else
    echo "Not sure is the domain is using LVM or not"
  fi

exit 0

