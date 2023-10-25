smartctl /dev/nvme0n1 --all | grep -E "Data Units Written:\s+[0-9,]+"

START=$(tail -n 1 .ssd_write_history |  tr ',' '\n' | head -n 1)
NOW=$(date '+%m/%d/%Y %H:%M:%S')
END=$(date --date "$NOW" +%s)
SECONDS=`echo "($END - $START)" | bc`
echo "Uptime:                             $SECONDS seconds [ts: $START]"

UNITS_START=$(tail -n 1 .ssd_write_history |  tr ',' '\n' | tail -n 1)
UNITS_NOW=$(smartctl /dev/nvme0n1 --all | grep -Eo "Data Units Written:\s+[0-9,]+" | sed -e $'s/[^0-9]//g')
UNIT_RATE=`echo "scale=4; ($UNITS_NOW - $UNITS_START) / ($SECONDS / 3600)" | bc`
DATA_RATE=`echo "scale=4; (($UNITS_NOW - $UNITS_START)/2) / ($SECONDS / 3600)" | bc`
echo "Burn rate:                          $DATA_RATE MB/hour [$UNIT_RATE units/hour]"
