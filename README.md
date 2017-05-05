## KVM-BUILD

A lightweight private cloud solution

This set of scripts creates and administrates a set of Linux distributions running as virtual machines on bare metal. 
Automating installations of base "golden" images, spawning fresh vms at light speed, destroying unneeded slaves are some of the features here included.
These scripts are well tested and have been used in production environments, mostly in connection with jenkins and the need for fresh build and deploy slaves, but also to run small websites
and services. 

I am perfectly aware of the fact that this is not the most elegant possible implementation (bash is bash), but is also very compact and lightweight, and i have tried very hard to keep my
coding neatly organized and well commented, so it is easy to debug. 

The scripts in the actual format are meant to be used on an Ubuntu xenial installation, being it your laptop or a server, and provide an easy implementation of a
"private cloud" using qemu-kvm, qemu-img, libvirt and libguestfs. Common distributions as Ubuntu 16, Debian 8, Centos 7 are supported and tested, and more flavours will be added later.

The spawning process is quite fast ( less than 60 s ) and the size of the installations remains very compact because the spawns use a read only "golden image" ( a standard installation of the
corresponding Linux distribution ) as a backing file for the ( qcow2 formatted ) filesystem the spawn OS is using, in a "snapshot" or "diff" fashion. Once the spawn has booted
it is possible to decouple the vm from its backing file and consolidate an autonomous image using the "consolidate" script here included.

The network is handled using the default in qemu-kvm, that is, a virbr0 bridge used by the vms.
This because there can be vary many possible network setups, and my wish was to find a common ground to laptop and server use of these scripts.
It works just fine, but there is no implementation (yet) to expose ports and services to the outside world, unless your environment allows it per default. 
Let me know if you have good ideas about how to implement a more sophisticated approach. 

Feel free to contribute and report bugs, or implement new features, possibly sending pull requests. Bring what you expect to find.
Send me some flowers or buy me a beer if you find these tools useful. 

## PREREQUISITES

* An OK level of knowledge of kvm and and virsh commands. 
* An Ubuntu 16.04 "xenial" hypervisor ( but the scripts will work fine also on centos7 / rhel6, although the paths to "virsh" and other commands will need to be adjusted ).
* qemu-kvm, qemu-utils, libguestfs-tools, virtinst, libvirt-bin, qemu-utils, arp packages installed. 
* enough diskspace to host the golden images ( defaulted to 12G per distribution ) in the default ubuntu location for qemu-kvm ( /var/lib/libvirt/images ).

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

Note that debian and centos machines will allow root access using the fancy "porcodio" password which is totally insecure to use.
Ubuntu defaults to a username "sub" with the same password, having sudo privileges. 
Further implementations should improve this aspect in the future, in the meantime these (quite silly) values can be edited in the files/ks/$distro/preseed or ks file.

### #2 Prepare the golden image

Once you have an "original" installation, you need to clean it up from all the elements that makes it an unique installation, as ssh hostkeys, mac adresses, logfiles, machine ids and so on.
This because we are going to use the images as a base to create clones that are all different from each other, and unique hosts.
So we need to turn the "original" image into a "golden image", that is an image prepared for cloning like there is no tomorrow.

run for example:

./prepare-golden.sh centos7
./prepare-golden.sh debian8
./prepare-golden.sh ubuntu16

The script will automatically find the corresponding base installation image, copy it to a new file, clean up the installation from the previously named "identifiers", and adjust the permissions
of the resulting images. Note that if at, AT ANY TIME, the golden images will be tampered with, ALL the vms that are using them as backing files will be affected in unpredictable and possibly
irreparable ways. You should not move the golden images to new locations in the filesystem for example. But is perfectly possible to decouple any of your spawned vms from the "commonly used" 
golden image by running the consolidate.sh script on them, although it requires the instance to be shut down.

### #3 SPAWN THE VMS

Once the the golden images are ready, you can start spawning vms. 
The script is very simple, and takes the distribution name and a user defined vm name as an argument.
It establishes a new qcow2 image for the filesystem using the golden image as a backing file, clones the kvm configuration file, and boots the vm.
Once the boot is complete and successful, an IP address is returned. You can then ssh in the new machine, or use "virsh console" to access the tty (in case there is some network problem). 

TODO: at the moment the values for memory amount and CPU count are hardcoded. Once the machine is up, is possible to edit the xml file in /etc/libvirt/qemu and reboot. 
In the future should be possible to give RAM and CPU count as an argument, but not yet. 

run for example

./spawn.sh ubuntu16 frontend

### #4 NUKE A VM

If you ever need to delete a machine, you can use the nuke.sh script. 
It will destroy the machine, remove the configuration file, and delete the image, so nothing will be there afterwards. 
It asks for confirmation. 

run for example

./nuke.sh ubuntu16.frontend

### #5 CONSOLIDATE A VM

Run this script if you want to detach a vm from the golden image. 
The vm should be powered off when running this command. It will dump the golden image and the vm image that is backing it into a new, independent image. 
Obviously the size of the result vm image will be a sum of the two. 

run for example

./consolidate.sh centos7.backend
 
### #6 DETECT THE IP OF A VM

Run this script if you need to find out about which IP is assigned to a certain (running) vm. 

run for example 

./detect.sh centos7.backend

## LICENSE

Most of the work to produce these scripts ( although these have been later on modified quite heavily ) i have done while working as an infrastructure engineer at Cfengine AS. 
Before ending my professional relationship with the company, i have asked about the possibility to publish these scripts and received a positive response, as long as they 
were published under the Apache license. I added the copyright message for the license to apply correctly.
