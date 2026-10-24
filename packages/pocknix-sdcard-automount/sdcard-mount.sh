#!/bin/bash
# sdcard-mount.sh — pocknix port of Valve's SteamOS SD-card automount helper.
#
# Called by 99-pocknix-sdcard-automount.rules (via systemd-run) on insert/removal of an ext4
# mmcblk partition. It mounts the card under /run/media, hands ownership to the Steam session
# user, and — the part a bare udev mount rule is missing — tells the RUNNING Steam client about
# it over its pipe with steam://addlibraryfolder, so the card actually shows up in the gamescope
# UI's Storage list. Without that IPC call Steam never surfaces a live-inserted card.
#
# Adapted from Valve's /usr/lib/hwsupport/sdcard-mount.sh. Three pocknix-specific changes vs Valve:
#   1. Session user is uid 1001 (`deck`), NOT Valve's 1000 — on pocknix uid 1000 is `alarm`.
#   2. The steam:// URL is sent via the NATIVE ARM client (~/.local/share/Steam/steamrtarm64/steam);
#      Valve's ./.steam/root/ubuntu12_32/steam is the x86 bootstrap and won't execute on aarch64.
#   3. The card is mounted with an ext4 idmap that swaps SteamOS's deck uid/gid (1000) with ours
#      (1001). Every SteamOS device numbers `deck`=1000, which is why an ext4 card roams freely
#      between them. pocknix numbers `deck`=1001, so a card written elsewhere lands on-disk as 1000
#      and Steam (running as 1001) can't write into steamapps -> "Missing file privileges". The
#      idmap presents on-disk 1000 as our 1001 and writes our files back to disk as 1000, so a
#      single card moves between a pocknix device and a real SteamOS device untouched. This
#      replaces Valve's post-mount `chown` of the mount root, which only re-owned the top dir
#      (leaving steamapps/ unwritable) and stamped an on-disk 1001 that broke the card elsewhere.

usage()
{
    echo "Usage: $0 {add|remove} device_name (e.g. mmcblk0p1)"
    exit 1
}

if [[ $# -ne 2 ]]; then
    usage
fi

ACTION=$1
DEVBASE=$2
DEVICE="/dev/${DEVBASE}"

# Never touch partitions of the disk we booted from: when the OS itself runs off an SD
# card, the udev add events for the BOOT SD's own partitions land here too, and trying
# to (re)mount the running root fails every boot as a failed transient unit. Same story
# after an internal install (root on /dev/sda): a udev replay for sda* must not match.
ROOT_DISK="$(lsblk -no PKNAME "$(findmnt -no SOURCE /)" 2>/dev/null | head -1)"
if [[ -n "${ROOT_DISK}" && "${DEVBASE}" == "${ROOT_DISK}"* ]]; then
    echo "ignoring ${DEVBASE}: partition of the boot disk (${ROOT_DISK})"
    exit 0
fi

# The Steam session user (pocknix: deck = 1001; NOT Valve's 1000 = alarm here).
STEAM_UID="$(id -u deck 2>/dev/null || echo 1001)"
# SteamOS's deck uid/gid — what a foreign card's files are owned by on disk. Adjacent to ours.
STEAMOS_UID=1000
STEAM_HOME=/home/deck
# Native ARM client + its runtime libs (see /usr/bin/pocknix-steam for the same contract).
STEAM_CLIENT_DIR="${STEAM_HOME}/.local/share/Steam/steamrtarm64"
STEAM_LDLP="${STEAM_CLIENT_DIR}:${STEAM_HOME}/.local/share/Steam/lib/aarch64-linux-gnu"

MOUNT_LOCK="/run/sdcard-mount.lock"
exec 9>"${MOUNT_LOCK}"
if ! flock -w 10 9; then
    echo "$MOUNT_LOCK is active: ignoring action $ACTION"
    exit 1
fi

# See if this drive is already mounted, and if so where
MOUNT_POINT=$(findmnt -no TARGET -- "${DEVICE}" 2>/dev/null | head -1)
MOUNT_FSTYPE=$(findmnt -no FSTYPE -- "${DEVICE}" 2>/dev/null | head -1)

# From https://gist.github.com/HazCod/da9ec610c3d50ebff7dd5e7cac76de05
urlencode()
{
    [ -z "$1" ] || echo -n "$@" | hexdump -v -e '/1 "%02x"' | sed 's/\(..\)/%\1/g'
}

# Send a steam:// URL to the running client for the deck user, in that user's systemd session so it
# inherits the right DBus/pipe env. No-op (best effort) if Steam isn't running.
notify_steam()
{
    local url_action=$1   # addlibraryfolder | removelibraryfolder
    local url=$2
    if pgrep -x "steam" > /dev/null; then
        timeout 10 systemd-run -M ${STEAM_UID}@ --user --collect --wait \
            /bin/sh -c "cd '${STEAM_CLIENT_DIR}' && LD_LIBRARY_PATH='${STEAM_LDLP}' timeout 8 ./steam steam://${url_action}/${url}" \
            || echo "notify_steam: steam://${url_action} send failed (non-fatal)"
    fi
}

sync_sdcard_roms()
{
    local action=$1
    local mp=$2
    if [[ -x /usr/bin/pocknix-sdcard-roms-sync ]]; then
        runuser -u deck -- env HOME="${STEAM_HOME}" /usr/bin/pocknix-sdcard-roms-sync "${action}" "${mp}" \
            || echo "sync_sdcard_roms (${action}): failed (non-fatal)"
    fi
}

do_mount()
{
    if [[ -n ${MOUNT_POINT} ]]; then
        echo "Warning: ${DEVICE} is already mounted at ${MOUNT_POINT}"
        exit 1
    fi

    # Get info for this drive: $ID_FS_LABEL, and $ID_FS_TYPE
    dev_json=$(lsblk -o PATH,LABEL,FSTYPE --json -- "$DEVICE" | jq '.blockdevices[0]')
    ID_FS_LABEL=$(jq -r '.label | select(type == "string")' <<< "$dev_json")
    ID_FS_TYPE=$(jq -r '.fstype | select(type == "string")' <<< "$dev_json")

    # Figure out a mount point to use, namespaced under the deck user like modern SteamOS.
    # Sanitize spaces/unsafe characters in Windows/Android exFAT labels so paths stay shell-safe.
    LABEL=$(echo "${ID_FS_LABEL}" | tr -cs 'A-Za-z0-9._-' '_' | sed 's/^_//;s/_$//')
    if [[ -z "${LABEL}" ]]; then
        LABEL=${DEVBASE}
    elif findmnt -rn -M "/run/media/deck/${LABEL}" >/dev/null 2>&1; then
        # Already in use, make a unique one
        LABEL+="-${DEVBASE}"
    fi
    MOUNT_POINT="/run/media/deck/${LABEL}"

    echo "Mount point: ${MOUNT_POINT} (fstype: ${ID_FS_TYPE})"

    /bin/mkdir -p -- "${MOUNT_POINT}"

    case "${ID_FS_TYPE}" in
        ext4)
            # Global mount options, plus the deck<->SteamOS uid/gid swap (see header note 3). The map is
            # full identity except the two singletons that trade STEAMOS_UID and STEAM_UID, so every other
            # owner (root-owned lost+found, etc.) passes through unchanged instead of becoming `nobody`.
            # STEAM_UID is STEAMOS_UID+1, so the trailing identity range starts at STEAM_UID+1.
            TAIL_START=$((STEAM_UID + 1))
            TAIL_COUNT=$((4294967295 - TAIL_START))
            IDMAP="u:0:0:${STEAMOS_UID} u:${STEAMOS_UID}:${STEAM_UID}:1 u:${STEAM_UID}:${STEAMOS_UID}:1 u:${TAIL_START}:${TAIL_START}:${TAIL_COUNT}"
            IDMAP+=" g:0:0:${STEAMOS_UID} g:${STEAMOS_UID}:${STEAM_UID}:1 g:${STEAM_UID}:${STEAMOS_UID}:1 g:${TAIL_START}:${TAIL_START}:${TAIL_COUNT}"
            OPTS="rw,noatime,X-mount.idmap=${IDMAP}"
            ;;
        exfat)
            # Android portable storage SD card (exFAT): mount owned by deck (1001) so ES-DE, RetroArch,
            # and standalone emulators have full read/write access to ROMs, BIOS, and saves.
            OPTS="rw,noatime,uid=${STEAM_UID},gid=${STEAM_UID},fmask=0022,dmask=0022,iocharset=utf8,errors=remount-ro"
            ;;
        vfat)
            # FAT32 SD card: mount owned by deck (1001) with UTF-8 filenames.
            OPTS="rw,noatime,uid=${STEAM_UID},gid=${STEAM_UID},fmask=0022,dmask=0022,utf8,shortname=mixed,errors=remount-ro"
            ;;
        *)
            echo "Error mounting ${DEVICE}: unsupported fstype: ${ID_FS_TYPE} - ${dev_json}"
            /bin/rmdir -- "${MOUNT_POINT}" 2>/dev/null
            exit 2
            ;;
    esac

    if ! /bin/mount -t "${ID_FS_TYPE}" -o "${OPTS}" -- "${DEVICE}" "${MOUNT_POINT}"; then
        echo "Error mounting ${DEVICE} (status = $?)"
        /bin/rmdir -- "${MOUNT_POINT}"
        exit 1
    fi

    echo "**** Mounted ${DEVICE} (${ID_FS_TYPE}) at ${MOUNT_POINT} ****"

    # Only register ext4 cards as Steam library folders (Proton prefixes require POSIX symlinks/perms).
    if [[ "${ID_FS_TYPE}" == "ext4" ]]; then
        notify_steam addlibraryfolder "$(urlencode "${MOUNT_POINT}")"
    fi

    # Discover and link shared ROMs/BIOS/ES-DE media on any mounted SD card (ext4, exfat, or vfat).
    sync_sdcard_roms add "${MOUNT_POINT}"
}

do_unmount()
{
    if [[ "${MOUNT_FSTYPE}" == "ext4" && -n "${MOUNT_POINT}" ]]; then
        notify_steam removelibraryfolder "$(urlencode "${MOUNT_POINT}")"
    fi

    if [[ -z ${MOUNT_POINT} ]]; then
        echo "Warning: ${DEVICE} is not mounted"
    else
        /bin/umount -l -- "${DEVICE}"
        echo "**** Unmounted ${DEVICE}"
    fi

    # Prune any dangling SD-card ROM/BIOS symlinks pointing into the unmounted card.
    sync_sdcard_roms remove "${MOUNT_POINT}"

    # Reap empty orphan mount points under /run/media/deck.
    for f in /run/media/deck/* ; do
        [[ -e $f ]] || continue
        if [[ -n $(/usr/bin/find "$f" -maxdepth 0 -type d -empty) ]]; then
            if ! findmnt -rn -M "$f" >/dev/null 2>&1; then
                echo "**** Removing mount point $f"
                /bin/rmdir "$f"
            fi
        fi
    done
}

case "${ACTION}" in
    add)
        do_mount
        ;;
    remove)
        do_unmount
        ;;
    *)
        usage
        ;;
esac
