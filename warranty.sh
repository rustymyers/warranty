#!/bin/bash
# warranty.sh
# Description: looks up Apple warranty info for 
# this computer, or one specified by serial number 

# Based on a script by Scott Russell, IT Support Engineer, 
# University of Notre Dame
# http://www.nd.edu/~srussel2/macintosh/bash/warranty.txt
# Edited to add the ASD Versions by Joseph Chilcote
# Last Modified: 09/16/2010
# Edited 02/10/2011
# Updated support url 
# Added function to write data to plist

###############
##  GLOBALS  ##
###############

# make sure you use a full path
PlistLocal="/Library/appwarranty.plist"
WarrantyTempFile="/tmp/warranty.txt"
AsdCheck="/tmp/asdcheck.txt"

if [[ $# == 0 ]] ; then
	SerialNumber=`system_profiler SPHardwareDataType | grep "Serial Number" | grep -v "tray" |  awk -F ': ' {'print $2'} 2>/dev/null`
else
	SerialNumber="${1}"
fi

[[ -n "${SerialNumber}" ]] && WarrantyInfo=`curl -k -s "https://selfsolve.apple.com/warrantyChecker.do?sn=${SerialNumber}&country=USA" | awk '{gsub(/\",\"/,"\n");print}' | awk '{gsub(/\":\"/,":");print}' | sed s/\"\}\)// > ${WarrantyTempFile}`

curl -k -s https://github.com/chilcote/warranty/raw/master/asdcheck -o ${AsdCheck} > /dev/null 2>&1


#################
##  FUNCTIONS  ##
#################

AddPlistString()
{
	# $1 is key name $2 is key value $3 plist location
	# example: AddPlistString warranty_script version1 /Library/ETC/appwarranty.plist
	/usr/libexec/PlistBuddy -c "add :"${1}" string \"${2}\"" "${3}"
}

SetPlistString()
{
	# $1 is key name $2 is key value $3 plist location
	# example: SetPlistString warranty_script version2 /Library/ETC/appwarranty.plist
	/usr/libexec/PlistBuddy -c "set :"${1}" \"${2}\"" "${3}"
}

GetWarrantyValue()
{
	grep ^"${1}" ${WarrantyTempFile} | awk -F ':' {'print $2'}
}
GetWarrantyStatus()
{
	grep ^"${1}" ${WarrantyTempFile} | awk -F ':' {'print $2'}
}
GetModelValue()
{
	grep "${1}" ${WarrantyTempFile} | awk -F ':' {'print $2'}
}
GetAsdVers()
{
	#echo "${AsdCheck}" | grep -w "${1}:" | awk {'print $1'}
	grep "${1}:" ${AsdCheck} | awk -F':' {'print $2'}
}

###################
##  CREATE PLIST ##
###################

if [[ ! -e "${PlistLocal}" ]]; then
	AddPlistString warrantyscript version1 "${PlistLocal}"
	for i in purchasedate warrantyexpires warrantystatus modeltype asd
	do
	AddPlistString $i unknown "${PlistLocal}"
	done
fi

###################
##  APPLICATION  ##
###################

echo "$(date) ... Checking warranty status"
InvalidSerial=`grep "serial number provided is invalid" "${WarrantyTempFile}"`

if [[ -e "${WarrantyTempFile}" && -z "${InvalidSerial}" ]] ; then
	echo "Serial Number    ==  ${SerialNumber}"

	PurchaseDate=`GetWarrantyValue PURCHASE_DATE`
	echo "PurchaseDate     ==  ${PurchaseDate}"
	SetPlistString purchasedate "${PurchaseDate}" "${PlistLocal}"

	WarrantyExpires=`GetWarrantyValue HW_END_DATE`
	echo "WarrantyExpires  ==  ${WarrantyExpires}"
	SetPlistString warrantyexpires "${WarrantyExpires}" "${PlistLocal}"

	WarrantyStatus=`GetWarrantyStatus HW_SUPPORT_COV_SHORT`
	echo "WarrantyStatus   ==  ${WarrantyStatus}"
	SetPlistString warrantystatus "${WarrantyStatus}" "${PlistLocal}"

	ModelType=`GetModelValue PROD_DESC`
	echo "ModelType        ==  ${ModelType}"
	SetPlistString modeltype "${ModelType}" "${PlistLocal}"

	AsdVers=`GetAsdVers "${ModelType}"`
	echo "ASD              ==  ${AsdVers}"
	SetPlistString asd "${AsdVers}" "${PlistLocal}"
else
	[[ -z "${SerialNumber}" ]] && echo "     No serial number was found."
	[[ -n "${InvalidSerial}" ]] && echo "     Warranty information was not found for ${SerialNumber}."
fi

exit 0