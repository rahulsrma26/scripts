SECONDS=$(uptime | grep -Eo "[0-9]+:[0-9]+:[0-9]+" | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
UNITS_WRITTEN=$(smartctl /dev/nvme0n1 --all | grep -Eo "Data Units Written:\s+[0-9,]+" | sed -e $'s/[^0-9]//g')
echo "$UNITS_WRITTEN data units written in $SECONDS seconds"
#result=$(($UNITS_WRITTEN / $SECONDS))
result=`echo "scale=4; $UNITS_WRITTEN / ($SECONDS / 3600)" | bc`
echo "$result units/hour"
