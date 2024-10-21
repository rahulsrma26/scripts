#!/bin/bash

# Download and install the script:
# curl -o /usr/local/sbin/smartwrt https://github.com/rahulsrma26/scripts/raw/main/manage/debian/smartwrt.sh
# chmod +x /usr/local/sbin/smartwrt

# Function to display the help message
show_help() {
    echo "smartwrt - A script to check the total bytes written on SSDs and NVMe drives."
    echo "version: 1.2.0"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -d devices  Specify the device(s) to check (e.g., sda, nvme0n1)."
    echo "              Multiple devices can be separated by commas (without space)."
    echo "              If not specified, the script will check all available disk devices."
    echo "  -l          List all supported device(s)."
    echo "  -s          Save the output to a file with timestamp."
    echo "  -a          Add daily cron job to save the output."
    echo "  -r          Remove daily cron job."
    echo "  -c          Clear the history."
    echo "  -h          Show this help message."
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
CRON_COMMAND="$0 -s"

SPECIFIED_DEVICES=""
LIST_DEVICES=0
SAVE_OUTPUT=0
SHOW_HELP=0
ASK_SETUP_CRON=0
CRON_ADD=0
CRON_REMOVE=0
CLEAR_HIST=0

# Parse command-line arguments
while getopts "d:lsarch" opt; do
    case "$opt" in
        d) SPECIFIED_DEVICES="$OPTARG" ;;
        l) LIST_DEVICES=1 ;;
        s) SAVE_OUTPUT=1 ;;
        a) CRON_ADD=1 ;;
        r) CRON_REMOVE=1 ;;
        c) CLEAR_HIST=1 ;;
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

# List all supported devices
if [[ $LIST_DEVICES -eq 1 ]]; then
    DEVICES=$(smartctl --scan | awk '{print $1}' | grep -E "sd|nvme" | sed 's/\/dev\///g')
    echo "Supported device(s): $DEVICES" | tr '\n' ',' | sed 's/,$/\n/'
    exit 0
fi

# check if both -a and -r are set
if [[ $CRON_ADD -eq 1 && $CRON_REMOVE -eq 1 ]]; then
    echo "Error: Cannot add and remove cron job at the same time."
    show_help
    exit 1
fi

if [[ ! -f "$OUTPUT_FILE" && $CRON_EXISTS -eq 0 ]]; then
    ASK_SETUP_CRON=1
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    touch "$OUTPUT_FILE"
fi

if [[ $ASK_SETUP_CRON -eq 1 ]]; then
    echo "Do you want to set up a daily cron job? (yes/no): "
    read -r ANS
    ANS=$(echo "$ANS" | tr '[:upper:]' '[:lower:]')

    if [[ "$ANS" == "yes" || "$ANS" == "y" ]]; then
        CRON_ADD=1
        CRON_REMOVE=0
    else
        echo "Daily cron job not set up. Skipping..."
    fi
fi

if [[ $CRON_ADD -eq 1 || $CRON_REMOVE -eq 1 ]]; then
    CRON_EXISTS=$(crontab -l | grep -c "$CRON_COMMAND")
fi

if [[ $CRON_REMOVE -eq 1 ]]; then
    if [[ $CRON_EXISTS -eq 1 ]]; then
        # Remove the cron job from the crontab
        crontab -l | grep -v "$CRON_COMMAND" | crontab -
        echo "Daily cron job has been removed."
    else
        echo "Daily cron job not found. Skipping..."
    fi
fi

if [[ $CRON_ADD -eq 1 ]]; then
    if [[ $CRON_EXISTS -eq 0 ]]; then
        if [[ -n $SPECIFIED_DEVICES ]]; then
            CRON_COMMAND="$CRON_COMMAND -d $SPECIFIED_DEVICES"
        fi
        # Add the cron job to the crontab
        (crontab -l 2>/dev/null; echo "0 0 * * * $CRON_COMMAND") | crontab -
        echo "Daily cron job has been added."
    else
        echo "Daily cron job already exists. Skipping..."
    fi
fi

if [[ $CLEAR_HIST -eq 1 ]]; then
    echo "Clearing the history..."
    echo -n > "$OUTPUT_FILE"
fi

# Get all devices
DEVICES=$(lsblk -d -o NAME,TYPE | grep disk | awk '{print $1}')

if [[ -z $SPECIFIED_DEVICES ]]; then
    # shellcheck disable=SC2206
    SPECIFIED_DEVICES=($DEVICES)
else
    IFS=',' read -r -a SPECIFIED_DEVICES <<< "${SPECIFIED_DEVICES[@]}"
fi

for DEVICE in "${SPECIFIED_DEVICES[@]}"; do
    TOTAL_BYTES=0
    echo "----------------------------------------"
    if [[ $(echo "$DEVICES" | grep -c "$DEVICE") -eq 0 ]]; then
        echo "Device $DEVICE not found. Skipping..."
        continue
    fi
    if [[ $DEVICE == sd* ]]; then
        SMART=$(smartctl -a "/dev/$DEVICE")
        # check using smartctl where the device is SSD or not
        ROTATION=$(echo "$SMART" | grep "Rotation Rate")
        if [[ -z $ROTATION ]]; then
            echo "Device $DEVICE not recognized. Skipping..."
            continue
        fi
        IS_SSD=$(echo "$ROTATION" | grep -c "Solid State")
        if [[ $IS_SSD -eq 1 ]]; then
            DEVICE_TYPE="SSD"
        else
            DEVICE_TYPE="HDD"
        fi
        SECTOR_SIZE=$(echo "$SMART" | grep "Sector Size" | head -n 1 | awk '{print $3}')
        printf 'Device: %s\nType: %s\nSector size: %s\n' "$DEVICE" "$DEVICE_TYPE" "$SECTOR_SIZE"
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
        DEVICE_TYPE="NVME"
        SECTOR_SIZE=$(echo "$SMART" | grep "LBA Size" | head -n 1 | awk '{print $NF}')
        printf 'Device: %s\nType: %s\nSector size: %s\n' "$DEVICE" "$DEVICE_TYPE" "$SECTOR_SIZE"
        UNITS_WRITTEN=$(echo "$SMART" | grep "Data Units Written" | tail -n 1 | awk '{print $4}' | sed 's/,//g')
        echo "Data units written: $UNITS_WRITTEN"
        TOTAL_BYTES=$((UNITS_WRITTEN * SECTOR_SIZE * 1000))
    else
        echo "Unsupported device type $DEVICE. Skipping..."
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
            echo "$NOW $DEVICE $DEVICE_TYPE $SECTOR_SIZE $UNITS_WRITTEN $TOTAL_BYTES" >> "$OUTPUT_FILE"
            echo "[Saved]"
        fi
    fi
done
