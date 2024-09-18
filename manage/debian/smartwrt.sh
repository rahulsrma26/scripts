#!/bin/bash

# Function to display the help message
show_help() {
    echo "Usage: $0 [-d device_name] [-h]"
    echo
    echo "Options:"
    echo "  -d device_name   Specify the device to check (e.g., sda, nvme0n1)."
    echo "                   If not specified, the script will check all available disk devices."
    echo "  -s               Save the output to a file with timestamp."
    echo "  -h               Show this help message."
    echo
}

UNIT_SCALE=$((1024 * 10))
simplify_units() {
    local VALUE=$1
    local UNIT="B"
    local RESULT=$VALUE
    if [[ $RESULT -gt $UNIT_SCALE ]]; then
        RESULT=$((RESULT / 1024))
        UNIT="KiB"
    fi
    if [[ $RESULT -gt $UNIT_SCALE ]]; then
        RESULT=$((RESULT / 1024))
        UNIT="MiB"
    fi
    if [[ $RESULT -gt $UNIT_SCALE ]]; then
        RESULT=$((RESULT / 1024))
        UNIT="GiB"
    fi
    if [[ $RESULT -gt $UNIT_SCALE ]]; then
        RESULT=$((RESULT / 1024))
        UNIT="TiB"
    fi
    echo "$RESULT $UNIT"
}

# Initialize variables
OUTPUT_FILE="$HOME/.smart_logs/written.log"
mkdir -p "$(dirname "$OUTPUT_FILE")"

SPECIFIED_DEVICE=""
SAVE_OUTPUT=0
SHOW_HELP=0

# Parse command-line arguments
while getopts "d:sh" opt; do
    case "$opt" in
        d) SPECIFIED_DEVICE="$OPTARG" ;;
        s) SAVE_OUTPUT=1 ;;
        h) SHOW_HELP=1 ;;
        *) show_help
           exit 1 ;;
    esac
done

# Show help if the -h flag is set
if [[ $SHOW_HELP -eq 1 ]]; then
    show_help
    exit 0
fi

# Get all devices
DEVICES=$(lsblk -d -o NAME,TYPE | grep disk | awk '{print $1}')

# If a device is specified, check if it exists
if [[ -n $SPECIFIED_DEVICE ]]; then
    if [[ $DEVICES != *$SPECIFIED_DEVICE* ]]; then
        echo "Device $SPECIFIED_DEVICE not found"
        exit 1
    fi
    DEVICES=("$SPECIFIED_DEVICE")
fi

for DEVICE in "${DEVICES[@]}"; do
    TOTAL_BYTES=0
    if [[ $DEVICE == sd* ]]; then
        SMART=$(smartctl -a "/dev/$DEVICE")
        # check using smartctl where the device is SSD or not
        IS_SSD=$(echo "$SMART" | grep "Rotation Rate" | grep -c "Solid State")
        if [[ $IS_SSD -eq 1 ]]; then
            IS_SSD="SSD"
        else
            IS_SSD="HDD"
        fi
        SECTOR_SIZE=$(echo "$SMART" | grep "Sector Size" | head -n 1 | awk '{print $3}')
        echo "Device: $DEVICE (Type: $IS_SSD); Sector size: $SECTOR_SIZE"
        UNITS_WRITTEN=$(echo "$SMART" | grep "Total_LBAs_Written"| tail -n 1 | awk '{print $NF}')
        if [[ $UNITS_WRITTEN -gt 0 ]]; then
            echo "Total LBAs written: $UNITS_WRITTEN"
            TOTAL_BYTES=$((UNITS_WRITTEN * SECTOR_SIZE))
        else
            UNITS_WRITTEN=$(echo "$SMART" | grep "Host_Writes_32MiB" | tail -n 1 | awk '{print $NF}')
            if [[ $UNITS_WRITTEN -gt 0 ]]; then
                echo "Host writes 32 MiB: $UNITS_WRITTEN"
                TOTAL_BYTES=$((UNITS_WRITTEN * 32 * 1024 * 1024))
            else
                echo "No data found"
            fi
        fi
    elif [[ $DEVICE == nvme* ]]; then
        SMART=$(smartctl -a "/dev/$DEVICE")
        IS_SSD="NVME"
        SECTOR_SIZE=$(echo "$SMART" | grep "LBA Size" | head -n 1 | awk '{print $NF}')
        echo "Device: $DEVICE (Type: $IS_SSD); Sector size: $SECTOR_SIZE"
        UNITS_WRITTEN=$(echo "$SMART" | grep "Data Units Written" | tail -n 1 | awk '{print $4}' | sed 's/,//g')
        echo "Data units written: $UNITS_WRITTEN"
        TOTAL_BYTES=$((UNITS_WRITTEN * SECTOR_SIZE))
    else
        echo "Unknown device type"
    fi
    if [[ $TOTAL_BYTES -gt 0 ]]; then
        SIMPLIFIED_BYTES=$(simplify_units $TOTAL_BYTES)
        echo "Total bytes written: $TOTAL_BYTES ($SIMPLIFIED_BYTES)"
        NOW=$(date +%s)
        LAST_RECORD=$(grep "$DEVICE" "$OUTPUT_FILE" | tail -n 1)
        if [[ -n $LAST_RECORD ]]; then
            LAST_TIMESTAMP=$(echo "$LAST_RECORD" | awk '{print $1}')
            LAST_RECORD_TIME=$(date -d @"$LAST_TIMESTAMP" +"%Y-%m-%d %H:%M:%S")
            LAST_BYTES=$(echo "$LAST_RECORD" | awk '{print $6}')
            BYTES_DIFF=$((TOTAL_BYTES - LAST_BYTES))
            TIME_DIFF=$((NOW - LAST_TIMESTAMP))
            SPEED=$((BYTES_DIFF / TIME_DIFF))
            SIMPLIFIED_BYTES_DIFF=$(simplify_units $BYTES_DIFF)
            echo "Bytes written: $BYTES_DIFF ($SIMPLIFIED_BYTES_DIFF) since $LAST_RECORD_TIME"
            DAY=$((24 * 3600 * BYTES_DIFF / TIME_DIFF))
            SIMPLIFIED_DAY=$(simplify_units $DAY)
            echo "Speed: $SPEED B/s (Estimated day writes: $SIMPLIFIED_DAY)"
        fi
        if [[ $SAVE_OUTPUT -eq 1 ]]; then
            echo "$NOW $DEVICE $IS_SSD $SECTOR_SIZE $UNITS_WRITTEN $TOTAL_BYTES" >> "$OUTPUT_FILE"
            echo "[Saved]"
        fi
    fi
done
