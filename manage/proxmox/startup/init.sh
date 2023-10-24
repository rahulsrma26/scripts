NOW=$(date '+%m/%d/%Y %H:%M:%S')
SECONDS=$(date --date "$NOW" +%s)
DATA_GB=$(/usr/sbin/smartctl /dev/nvme0n1 --all | grep -E "Data Units Written:\s+[0-9,]+" | grep -Eo "\[.+\]" | sed -e $'s/[][]//g')
DATA_UNITS=$(/usr/sbin/smartctl /dev/nvme0n1 --all | grep -Eo "Data Units Written:\s+[0-9,]+" | sed -e $'s/[^0-9]//g')
echo "$SECONDS,$DATA_GB,$DATA_UNITS" >> ~/.ssd_write_history
