#!/usr/bin/env bash
# Author: samba
# Description: wipe the disk LUKS key and the boot partition 


# disk autodiscovery is safer but if you want you can specify the disks
DISK=$(blkid  -ndrp| grep crypto_LUKS| awk -F: '{print $1}')
BOOT=$(mount | grep boot | awk '{print $1}')
RUN=0 # do not run the wipe by default
DRY=1 # run in dry-run by default

usage(){
    if [ $# -eq 0 ];then
        echo "Usage $0:
        -d|--disk           Specify the disk to wipe (default: $DISK)
        -b|--boot           Specify the boot partition to wipe (default: $BOOT)
        -n|--dry-run        Dry run, do not perform any action (default: on)
        -r|--run            Run the script, wipe the disks, NO WAY BACK (default: off)
        -h|--help           Print this help message
        "
    fi
    exit 0
}
error(){
    echo "ERROR: $* "
    exit 1
}
info(){
    echo "INFO: $*"
}


check_disk(){
    [ $1 == "" ] && error "no disk assigned to check_disk"
    DISK="$1"
    if [ $(fdisk -l | grep -c $DISK) -ne 0 ];then
        info "Found $DISK, ready to wipe"
    else
        error "$DISK not found."
    fi
}
wipe_disk(){
    # wipe the LUKS key
    [ $1 == "" ] && error "nothing assigned to check_disk"
    DISK="$1"
    if [ $DRY -eq 1 ];then
        echo "[DRYRUN]: wiping $DISK, please wait..."
        echo "[DRYRUN]: head -c 1052672 /dev/zero > $DISK; sync"
    else
        info "wiping $DISK, please wait..."
        head -c 1052672 /dev/zero > $DISK; sync
    fi
}
wipe_boot(){
    # wipe the boot partition
    [ $1 == "" ] && error "nothing assigned to wipe_boot"
    DISK="$1"
    if [ $DRY -eq 1 ];then
        echo "[DRYRUN]: wiping $DISK, please wait..."
        echo "[DRYRUN]: dd if=/dev/zero of=$DISK bs=1M"
    else
        info "wiping $DISK, please wait..."
        dd if=/dev/zero of=$DISK bs=1M
    fi
}

[ $# -eq 0 ] && usage

while [ $# -ne 0 ];do
    case $1 in
        -d|--disk)
            shift
            DISK="$1"
            BOOT=""
            ;;
        -b|--boot)
            shift
            BOOT="$1"
            DISK=""
            ;;
        -r|--run)
            RUN=1
            DRY=0
            ;;
        -n|--dry-run)
            DRY=1
            ;;
        *)
            usage
            ;;
    esac
    shift
done


if [ "$DISK" != "" ];then
    info "wipe disk: $DISK"
    check_disk $DISK
    wipe_disk $DISK
fi
if [ "$BOOT" != "" ];then
    info "wipe boot partition: $BOOT"
    check_disk $BOOT
    wipe_boot $BOOT
fi

exit 0
