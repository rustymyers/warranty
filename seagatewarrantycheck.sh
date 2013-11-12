#!/bin/bash

# Written by Rusty Myers
# 2013-11-12

# Check Seagate repair program

#curl  "https://supportform.apple.com/201107/SerialNumberEligibilityAction.do?cb=iMacHDCheck.response&sn=$(ioreg -c "IOPlatformExpertDevice" | awk -F '"' '/IOPlatformSerialNumber/ {print $4}')" 2>/dev/null

VERBOSE=   #Set to 1 to see verbose

# Pass list of serials as first argument
for i in $(cat "${1}"); do

if [ "${VERBOSE}" ]; then 
    echo "VERBOSE"
	echo "Checking ${i}"
fi

SerialNumber="${i}"
echo -n "SerialNumber: $SerialNumber   -- "
curl "https://supportform.apple.com/201107/SerialNumberEligibilityAction.do?cb=iMacHDCheck.response&sn=${SerialNumber}" 2>/dev/null | awk -F: '{print $3}' | tr -d \"}\) 

done

exit 0
