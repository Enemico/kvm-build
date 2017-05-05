## YOUR OWN, PERSONAL, CLOUD'ISH

This set of scripts creates and administrates a set of Linux distributions running as virtual machines on bare metal. 
Automating installations of base "golden" images, spawning fresh vms at light speed, destroying unneeded slaves are some of the features here included.
These basic functions are well tested and have been used in production environments.

The scripts in the actual format are meant to be used on an Ubuntu xenial installation, being it your laptop or a server, and provide an easy implementation of a
"private cloud" using qemu-kvm, qemu-img, libvirt and libguestfs. Common distributions as Ubuntu 16, Debian 8, Centos 7 are supported and tested, and more flavours will be added later.

The spawning process is quite fast ( less than 60 s ) and the size of the installations remains very compact because the spawns use a read only "golden image" ( a standard installation of the
corresponding Linux distribution ) as a backing file for the ( qcow2 formatted ) filesystem the spawn OS is using, in a "snapshot" fashion. Once the spawn has booted
it is possible to decouple the vm from its backing file and consolidate an autonomous image using the "consolidate" script here included.

Feel free to contribute and report bugs, or implement new features, possibly sending pull requests. Bring what you expect to find.
Send me some compliments or buy me a beer if you find these tools useful. 

## PREREQUISITES

* Ubuntu 16.04 "xenial" ( but the scripts will work fine also on centos7 / rhel6, although the paths to "virsh" and other commands will need to be adjusted )
* qemu-kvm, qemu-utils, libguestfs-tools, virtinst, libvirt-bin, qemu-utils, arp
* enough diskspace to host the golden images ( defaulted to 12G per distribution ) in the default ubuntu location for qemu-kvm ( /var/lib/libvirt/images )

## PRINCIPLES OF OPERATION

### #1 Build installation

Once the scripts are cloned, you have to start building your golden images you will use as a backing file for your future virtual machines.
This process is kind of time-consuming, but it will be done only once for every flavour of Linux you intend to use. I have anyway automated this process as much as
possible, including here and feeding preseed or ks files ( depending on the distribution ) to the virt-install command in the script, so that the installation will be completely automated 
without the need for any human interaction. It just takes some time, depending on how fast your disk / internet connection is. 
I defaulted ( hardcoded ) the amount of CPUs to one for obvious reasons, but it is perfectly possible to adjust the value, if you know what you are doing.

run for example: 

./build-installation.sh centos7
./build-installation.sh debian8
./build-installation.sh ubuntu16

Once the installation is complete, you will be inside a freshly installed host.
The vm will be named as "$distro.original" (for example "debian8.original") 
Exit, shutdown the vm using "virsh shutdown $distro.original". You are done here. 

### #2 Prepare the golden image

Once you have an "original" installation, you need to clean it up from all the elements that makes it an unique installation, as ssh hostkeys, mac adresses, logfiles, machine ids and so on.
This because we are going to use the images as a base to create clones that are all different from each other, and unique hosts.
So we need to turn the "original" image into a "golden image", that is an image prepared for cloning like there is no tomorrow.

run for example:

./prepare-golden.sh centos7
./prepare-golden.sh debian8
./prepare-golden.sh ubuntu16

The script will automatically find the corresponding base installation image, copy it to a new file, clean up the installation from the previously named "identifiers", and adjust the permissions
of the resulting images.

### #3 SPAWN THE VMS

Once the the golden images are ready, you can start spawning vms. 


