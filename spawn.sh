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


#set -x
VIRSH=/usr/bin/virsh
DISTRO=$1
VM=$2
CWD="/var/lib/libvirt/images"

### Am i Root check
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root, or preceded by sudo."
  echo "If sudo does not work, contact your system administrator."
  exit 1
fi

usage () {
  echo "usage: $0 [distro] [instance name]"
  echo "possible distros: centos6 / centos7 / debian6 / debian7"
  exit 1
}

### check the distro ( first ) argument
case "$1" in
### help
  -h | help | --help)
    usage
  ;;
### centos6
  -c6 | centos6 | c6)
    echo "CentOS 6 selected"
  ;;
### centos7
  -c7 | centos7 | c7)
    echo "CentOS 7 selected"
  ;;
### debian6
  -d6 | debian6 | d6)
    echo "Debian 6 (squeeze) selected"
  ;;

### debian7
  -d7 | debian7 | d7)
    echo "Debian 7 (wheezy) selected"
  ;;

### debian8
  -d8 | debian8 | d8)
    echo "Debian 8 (jessie) selected"
  ;;

### ubuntu16
  -u16 | ubuntu16 | u16)
    echo "Ubuntu 16.04 (xenial) selected"
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

## check if we are not risiking to overwrite some important image

if [ $VM == "original" ]; then
  echo "Sorry, "original" is a bad name here."
  exit 1
fi

if [ $VM == "golden" ]; then
  echo "Sorry, "golden" is a bad name here."
  exit 1
fi

## create a clone, referencing only to the copy
qemu-img create -b $CWD/${DISTRO}.golden.img -f qcow2 $CWD/${DISTRO}.${VM}.qcow2
check_exitcode

### clone the configuration file for kvm
/usr/bin/virsh dumpxml $DISTRO.original > /tmp/$DISTRO.original.xml
check_exitcode

### quickfix https://dev.cfengine.com/issues/7755
### change the cache type from none to unsafe
sed -i 's/none/unsafe/g' /tmp/$DISTRO.original.xml

# clone the configuration file using the original distro one, changing the image reference to point at the prepared image
virt-clone --original-xml /tmp/$DISTRO.original.xml --name ${DISTRO}.${VM} --preserve-data --file $CWD/${DISTRO}.${VM}.qcow2
check_exitcode


### inject standard SSH host keys ( the same for all possible machines we clone ).
## first step is to make sure the permissions for our local files are correct
# chmod 600 keys/ssh_host*
# chmod 644 keys/*.pub
#
# ## copy them into the clone
# /usr/bin/virt-copy-in -d ${DISTRO}.${VM} keys/ssh_host* /etc/ssh/

# /usr/bin/virt-copy-in -d ${DISTRO}.${VM} files/rc.local /etc/rc.local
# /usr/bin/virt-copy-in -d ${DISTRO}.${VM} $PWD/files/jenkins_authorized_keys /root

# As a backup plan, we make sure that the guest will generate some host keys if none are present
# ( after all, we removed the host keys in the golden image preparation script).
/usr/bin/guestfish -d ${DISTRO}.${VM} -i upload - /etc/rc.local <<EOF
#!/bin/bash

  if [ ! -d /root/.ssh ]; then
    mkdir /root/.ssh
  fi

  if [ -f /root/jenkins_authorized_keys ]; then
    cp /root/jenkins_authorized_keys /root/.ssh/authorized_keys
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/authorized_keys
  fi

  if [ ! -f /etc/ssh/ssh_host_dsa_key ]; then
     ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa > /dev/null 2>&1
     ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa > /dev/null 2>&1
  fi

  ## This reload the selinux policy for rpm based distros
  if [ -f /sbin/restorecon ]; then
    /sbin/restorecon -R -v /root/.ssh
  fi
EOF

#systemd...
if [ $DISTRO = "centos7" ]; then
    /usr/bin/guestfish -d ${DISTRO}.${VM} -i command "chmod a+x /etc/rc.local"
fi

if [ $DISTRO = "debian6" ]; then
/usr/bin/guestfish -d ${DISTRO}.${VM} -i upload - /etc/apt/sources.list <<EOF
    deb http://archive.debian.org/debian/ squeeze main non-free contrib
    deb-src http://archive.debian.org/debian/ squeeze main non-free contrib
    deb http://archive.debian.org/debian-security/ squeeze/updates main non-free contrib
    deb-src http://archive.debian.org/debian-security/ squeeze/updates main non-free contrib
EOF
fi

# start the machine!
virsh start ${DISTRO}.${VM}
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
if [ -z $IP ]; then
  echo "Waiting for the instance to boot"
  sleep 40
else
  echo "$IP has been assigned to ${DISTRO}.${VM} by DHCP"
fi

extract_address
echo "$IP has been assigned to ${DISTRO}.${VM} by DHCP"

