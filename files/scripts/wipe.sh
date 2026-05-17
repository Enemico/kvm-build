#!/usr/bin/env bash
# Description: wipe the disk LUKS key OR erase LUKS keyslots, and optionally wipe the boot partition

# Auto-discover LUKS device and boot partition
LUKS=$(blkid -ndrp | grep crypto_LUKS | awk -F: '{print $1}')
BOOT=$(mount | grep boot | awk '{print $1}')
MODE=""   # must be set to "key" or "partition" before executing
DRY=1     # dry-run by default
WIPE_BOOT=0

usage(){
    echo ""
    echo "Usage: $0 -k|-p [-b] [-r] [-n] [-h]"
    echo ""
    echo "  Two mutually exclusive LUKS wipe modes (pick one):"
    echo "    -k|--key            Zero the LUKS header on $LUKS"
    echo "                        Fast, destroys the header. Data is unrecoverable."
    echo "    -p|--partition      Erase all LUKS keyslots on $LUKS via cryptsetup"
    echo "                        Surgical: keyslots gone, rest of disk untouched."
    echo ""
    echo "  Optional:"
    echo "    -b|--boot           Also wipe the boot partition (default: $BOOT)"
    echo "    -r|--run            Live mode — actually perform the wipe (default: dry-run)"
    echo "    -n|--dry-run        Dry-run mode, no changes made (default: on)"
    echo "    -h|--help           Print this help message"
    echo ""
    exit 0
}

error(){
    echo "ERROR: $*"
    exit 1
}

info(){
    echo "INFO: $*"
}

check_disk(){
    [ -z "$1" ] && error "no disk assigned to check_disk"
    local LUKS="$1"
    if [ $(fdisk -l | grep -c $LUKS) -ne 0 ]; then
        info "Found $LUKS, ready to wipe"
    else
        error "$LUKS not found."
    fi
}

wipe_key(){
    # Zero the LUKS header — fast, destroys the superblock entirely
    local LUKS="$1"
    if [ $DRY -eq 1 ]; then
        echo "[DRYRUN]: zeroing LUKS header on $LUKS"
        echo "[DRYRUN]: head -c 1052672 /dev/zero > $LUKS; sync"
    else
        info "Zeroing LUKS header on $LUKS, please wait..."
        head -c 1052672 /dev/zero > $LUKS; sync
    fi
}

wipe_partition(){
    # Erase all LUKS keyslots via cryptsetup — surgical, does not touch the rest of the disk
    local LUKS="$1"
    which cryptsetup > /dev/null 2>&1 || error "cryptsetup not found, please install it"
    if [ $DRY -eq 1 ]; then
        echo "[DRYRUN]: erasing all LUKS keyslots on $LUKS via cryptsetup"
        echo "[DRYRUN]: cryptsetup erase $LUKS"
    else
        info "Erasing all LUKS keyslots on $LUKS via cryptsetup, please wait..."
        cryptsetup erase "$LUKS"
    fi
}

wipe_boot(){
    # Zero the boot partition entirely
    local BOOT="$1"
    if [ $DRY -eq 1 ]; then
        echo "[DRYRUN]: zeroing boot partition $BOOT"
        echo "[DRYRUN]: dd if=/dev/zero of=$BOOT bs=1M"
    else
        info "Zeroing boot partition $BOOT, please wait..."
        dd if=/dev/zero of=$BOOT bs=1M
    fi
}

[ $# -eq 0 ] && usage

while [ $# -ne 0 ]; do
    case $1 in
        -k|--key)
            [ "$MODE" = "partition" ] && error "-k and -p are mutually exclusive. Pick one."
            MODE="key"
            [[ -n "$2" && "$2" != -* ]] && { shift; LUKS="$1"; }
            ;;
        -p|--partition)
            [ "$MODE" = "key" ] && error "-k and -p are mutually exclusive. Pick one."
            MODE="partition"
            [[ -n "$2" && "$2" != -* ]] && { shift; LUKS="$1"; }
            ;;
        -b|--boot)
            WIPE_BOOT=1
            [[ -n "$2" && "$2" != -* ]] && { shift; BOOT="$1"; }
            ;;
        -r|--run)
            DRY=0
            ;;
        -n|--dry-run)
            DRY=1
            ;;
        -h|--help)
            usage
            ;;
        *)
            usage
            ;;
    esac
    shift
done

[ -z "$MODE" ] && error "You must specify a mode: -k to zero the LUKS header, or -p to erase keyslots via cryptsetup."
[ -z "$LUKS" ] && error "No LUKS device detected and none specified. Use -k or -p /dev/sdX to set one manually."
[ $WIPE_BOOT -eq 1 ] && [ -z "$BOOT" ] && error "Boot wipe requested but no boot partition detected. Specify one with -b /dev/sdX."

### Summary
echo ""
echo "========================================"
echo " wipe.sh — planned actions"
echo "========================================"
echo ""
if [ "$MODE" = "key" ]; then
    echo "  Operation : zero LUKS header (head /dev/zero)"
    echo "  Target    : $LUKS"
elif [ "$MODE" = "partition" ]; then
    echo "  Operation : erase LUKS keyslots (cryptsetup erase)"
    echo "  Target    : $LUKS"
fi
[ $WIPE_BOOT -eq 1 ] && echo "  Boot wipe : $BOOT"
echo ""
if [ $DRY -eq 1 ]; then
    echo "  Mode: DRY RUN — no changes will be made. Pass -r to run for real."
else
    echo "  Mode: LIVE — THIS WILL DESTROY DATA. THERE IS NO RECOVERY."
fi
echo ""
echo "========================================"
read -rep $'Are you sure you want to continue? y/n \n'
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

### Execute
check_disk "$LUKS"
if [ "$MODE" = "key" ]; then
    wipe_key "$LUKS"
elif [ "$MODE" = "partition" ]; then
    wipe_partition "$LUKS"
fi

if [ $WIPE_BOOT -eq 1 ]; then
    check_disk "$BOOT"
    wipe_boot "$BOOT"
fi

exit 0
