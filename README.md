This set of scripts creates and administrates a set of Linux distributions on bare metal. 
Automating installations of base "golden" images, spawning fresh clones of these at light speed, destroying the clones are some of the features here included.
These basic functions are well tested and have been used in production environments.

The scripts in the actual format are meant to be used on an Ubuntu xenial installation, being it your laptop or a server, and provide an easy implementation of a
"private cloud" using qemu-kvm, qemu-img, libvirt and libguestfs. Ubuntu 16.04, Debian 8, Centos 7 are supported and tested, and more flavours will be added later.
The spawning process is very fast and the size of the installations remains very compact because the spawns use a read only "golden image" ( a standard installation of the
corresponding Linux distribution ) as a backing file for the ( qcow2 formatted ) filesystem the spawn OS is using, in a "snapshot" fashion. Once the spawn has booted
it is possible to decouple the vm from its backing file and consolidate an autonomous image using the "consolidate" script here included.

## PREREQUISITES

* Ubuntu 16.04 "xenial" ( but the scripts will work fine also on centos7 / rhel6, although the paths to "virsh" and other commands will need to be adjusted )
* qemu-kvm, qemu-utils, libguestfs-tools, virtinst, libvirt-bin, qemu-utils, arp
* enough diskspace to host the golden images ( defaulted to 12G per distribution ) in the default ubuntu location for qemu-kvm ( /var/lib/libvirt/images )


