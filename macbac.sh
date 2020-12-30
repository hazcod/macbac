#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

#
#--------------------------------------------------------------------------------------------------------------------------------------
#

usage() {
    # show command cli usage help
    echo "Usage: $0 <status|list|snapshot|enable|disable>"
    exit 1
}

error() {
    # show an error message and exit
    echo -e "${RED}ERROR:${N} ${1}${NC}"
    exit 1
}

snapshot() {
    local volume="$2"

    if [ -z "$volume" ]; then
        echo "Assuming / is the volume we would like to snapshot."
        volume="/"
    fi

    if ! tmutil localsnapshot "$volume" | grep -v '^NOTE:'; then
        error "Could not snapshot ${volume}"
        exit 1
    fi

    echo -e "${GREEN}Snapshotted volume ${volume}${NC}"
}

enable() {
    if ! sudo tmutil enable; then
        error "Could not enable backups"
        exit 1
    fi

    echo -e "${GREEN}Enabled backups.${NC}"
}

disable() {
    if ! sudo tmutil disable; then
        error "Could not enable backups"
        exit 1
    fi

    echo -e "${YELLOW}Disabled backups.${NC}"
}

getVolumes() {
    ls -d /Volumes/*
}

getSnapshots() {
    local volume="$1"
    tmutil listlocalsnapshotdates "$volume" | tail -n +2 | xargs
    #listlocalsnapshots / | tail -n +2 | xargs | sed 's/com\.apple\.TimeMachine\.//g' | sed 's/\.local//'
}

listStatus() {
    status="$(tmutil currentphase)"
    
    if [ "$status" == "BackupNotRunning" ]; then
        echo -e "${BOLD}Status${NC}: Inactive"
        return
    fi

    if [ "$status" == "BackupError" ]; then
        echo -e "${BOLD}Status${NC}: ${RED}Error during backup${NC}"
        return
    fi

    echo -e "${BOLD}Status${NC}: ${GREEN}Running${NC}"
}

listSnapshots() {
    volumes=$(getVolumes)

    for volume in $(getVolumes); do
        # show current volume
        echo -e "${BOLD}${volume}${NC}"

        local snapshots

        # retrieve snapshots
        if ! snapshots="$(getSnapshots "$volume")"; then
            error "could not retrieve snapshots"
            exit 1
        fi

        # list all snapshots
        for snapshot in $snapshots; do
            IFS='-' read -ra parts <<< "$snapshot"
            dateStr="${parts[3]:0:2}:${parts[3]:2:2}"
            echo "> ${parts[0]}/${parts[1]}/${parts[2]} $dateStr"
        done

        # add extra space when we have multiple rows
        if (( ${#volumes[@]} > 1 )); then
            echo ""
        fi
    done
}

#
#--------------------------------------------------------------------------------------------------------------------------------------
#

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    usage
fi

case "$1" in
    "status")
        if [ $# -ne 1 ]; then
            usage
        fi
        
        listStatus
    ;;

    "list")
        if [ $# -ne 1 ]; then
            usage
        fi
        
        listSnapshots
    ;;

    "snapshot")
        if [ $# -ne 1 ]; then
            if [ $# -ne 2 ]; then
                usage
            fi
        fi
        
        snapshot "$1"
    ;;

    "enable")
        if [ $# -ne 1 ]; then
            if [ $# -ne 2 ]; then
                usage
            fi
        fi
        
        enable "$1"
    ;;

    "disable")
        if [ $# -ne 1 ]; then
            if [ $# -ne 2 ]; then
                usage
            fi
        fi
        
        disable "$1"
    ;;

    *)
        usage
    ;;
esac