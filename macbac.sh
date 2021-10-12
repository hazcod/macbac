#!/usr/bin/env bash

PACKAGE_NAME="com.hazcod.macbac"
PLIST_PATH="$HOME/Library/LaunchAgents/${PACKAGE_NAME}.plist"

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
    echo "Usage: $0 <status|list|snapshot|enable|disable|schedule|deschedule|prune|next> <...>"
    exit 1
}

error() {
    # show an error message and exit
    >&2 echo -e "${RED}ERROR:${N} ${1}${NC}"
    exit 1
}

realpath() {
  OURPWD=$PWD
  cd "$(dirname "$1")"
  LINK=$(readlink "$(basename "$1")")
  while [ "$LINK" ]; do
    cd "$(dirname "$LINK")"
    LINK=$(readlink "$(basename "$1")")
  done
  REALPATH="$PWD/$(basename "$1")"
  cd "$OURPWD"
  echo "$REALPATH"
}

deschedule() {
    if [ ! -f "${PLIST_PATH}" ]; then
        error "a schedule was not configured"
        exit 1
    fi

    launchctl stop "${PACKAGE_NAME}" 2>/dev/null

    if ! launchctl unload "$PLIST_PATH" || ! rm "${PLIST_PATH}"; then
        error "could not disable the schedule"
        exit 1
    fi

    echo -e "Removed previous snapshot schedule."
}

showNext() {
    parts=$(grep StartCalendarInterval "$PLIST_PATH" -C2 | tail -n1)
    mode=$(echo "$parts" | cut -d '>' -f 2 | cut -d '<' -f 1)
    number=$(echo "$parts" | cut -d '>' -f 4 | cut -d '<' -f 1)

    if [[ "$mode" == "" ]]; then
        error "No schedule detected. Did you run 'schedule'?"
        exit 1
    fi

    local now
    local unit

    if [[ "$mode" == "Minute" ]]; then
        now=$(date +'%M')
        unit="minutes"
    fi

    if [[ "$mode" == "Hour" ]]; then
        now=$(date +'%H')
        unit="hours"
    fi

    diff="$((number - now))"
    if (( diff < 0 )); then
        diff=$((diff+60))
    fi

    echo "Your next snapshot is scheduled in the next ${diff} ${unit}."
    return
}

schedule() {
    local mode="$1"
    local keep="$2"

    interval=""
    if [ "$mode" == "hourly" ]; then
        interval="<key>Minute</key><integer>$(($(date +%M) +1))</integer>"
        if [ -z "$keep" ]; then
            keep="24"
        fi
    elif [ "$mode" == "daily" ]; then
        interval="<key>Hour</key><integer>$(($(date +%H) -1))</integer>"
        if [ -z "$keep" ]; then
            keep="7"
        fi
    else
        error "invalid schedule mode: ${mode}"
        exit 1
    fi

    if [ -f "$PLIST_PATH" ]; then
        echo "Removing previous schedule..."
        deschedule
    fi

    echo "Installing daemon config to ${PLIST_PATH}"
    cat >"$PLIST_PATH" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PACKAGE_NAME}</string>
    <key>Nice</key>
    <integer>20</integer>
    <key>StandardOutPath</key>
    <string>/tmp/macbac.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/macbac.err</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(realpath $0)</string>
        <string>snapshot</string>
        <string>${keep}</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        ${interval}
    </dict>
</dict>
</plist>
EOL

    echo "Loading config to enable schedule..."
    if ! launchctl load "$PLIST_PATH" || ! launchctl start "${PACKAGE_NAME}"; then
        error "Could not enable the schedule"
        exit 1
    fi

    echo -e "${GREEN}Scheduled ${mode} snapshots!${NC}"
}

prune() {
    local volume="$1"
    local amount="$2"

    if [[ ${amount} -le 0 ]]; then
        exit 0
    fi

    IFS=$'\n' read -r -d '' -a snapshots < <(tmutil listlocalsnapshotdates "$volume" | tail -n +2 | sort)

    if [[ ${#snapshots[@]} -eq 0 ]]; then
        echo "No snapshots to purge"
        exit 0
    fi

    if [[ ${amount} -gt ${#snapshots[@]} ]]; then
        amount=0
    else
        amount=$((${#snapshots[@]} - amount))
    fi

    echo "Pruning ${amount} of ${#snapshots[@]} snapshots for ${volume}"
    
    counter="$amount"
    for snapshot in "${snapshots[@]}"; do
        if [[ $counter -le 0 ]]; then
            break
        fi

        echo "Pruning snapshot ${snapshot} (${counter}/${amount})"

        if ! tmutil deletelocalsnapshots "${snapshot}" >/dev/null; then
            error "could not prune local snapshot ${snapshot}"
            exit 1
        fi

        counter=$((counter -1))
    done
}

snapshot() {
    local volume="$1"
    local pruneAmount="$2"

    if [ -z "$volume" ]; then
        echo "Assuming / is the volume we would like to snapshot."
        volume="/"
    fi

    if ! tmutil localsnapshot "${volume}" | grep -v '^NOTE:'; then
        error "Could not snapshot ${volume}"
        exit 1
    fi

    echo -e "${GREEN}Snapshotted volume ${volume}${NC}"

    if [ -n "$pruneAmount" ] && (( pruneAmount > 0 )); then
        prune "$volume" "$pruneAmount"
    fi
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
        echo -e "${BOLD}Backup Status${NC}: Inactive"
        return
    fi

    if [ "$status" == "BackupError" ]; then
        echo -e "${BOLD}Backup Status${NC}: ${RED}Error during backup${NC}"
        return
    fi

    echo -e "${BOLD}Backup Status${NC}: ${GREEN}Running${NC}"
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
            dateStr="${parts[3]:0:2}:${parts[3]:2:2}:${parts[3]:4:2}"
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

if [ $# -lt 1 ]; then
    usage
fi

case "$1" in
    "status")
        if [[ "$#" -gt 1 ]]; then
            usage
        fi
        
        listStatus
    ;;

    "list")
        if [[ "$#" -gt 1 ]]; then
            usage
        fi
        
        listSnapshots
    ;;

    "snapshot")
        if [[ "$#" -gt 2 ]]; then
            usage
        fi
        
        snapshot "/" "$2"
    ;;

    "enable")
        if [[ "$#" -gt 1 ]]; then
            usage
        fi
        
        enable
    ;;

    "disable")
        if [[ "$#" -gt 1 ]]; then
            usage
        fi
        
        disable
    ;;

    "schedule")
        if [[ "$#" -gt 3 ]]; then
            usage
        fi
        
        schedule "$2" "$3"
    ;;

    "deschedule")
        if [[ "$#" -gt 1 ]]; then
            usage
        fi
        
        deschedule
    ;;

    "prune")
        if [[ "$#" -gt 2 ]]; then
            usage
        fi
        
        prune "/" "$2"
    ;;

    "next")
        if [[ "$#" -gt 1 ]]; then
            usage
        fi

        showNext
    ;;

    *)
        usage
    ;;
esac