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
# Added function to cycle through a csv file
# Complete rewrite:




###############
##  GLOBALS  ##
###############

# make sure you use a full path
WarrantyTempFile="/tmp/warranty.txt"
AsdCheck="/tmp/asdcheck.txt"
Output="."
Format="stdout"
# PlistLocal="/tmp/appwarranty.plist"


#################
##  FUNCTIONS  ##
#################

help()
{
cat<<EOF

Input:
	no flags = use this computers serial
	-c = loop through csv file
		 processing a csv file will only output to a 
		 csv file. other output formats will be ignored
	-s = specify serial number

Output:
	-f [csv or plist] = format output file to csv or plist
	-o /path/to/output # Do not include filename
	
Defaults:
	WarrantyTempFile="/tmp/warranty.txt"
	AsdCheck="/tmp/asdcheck.txt"
	Output="."
	Format="stdout"

Examples:
	Default Use - Uses machine serial, prints to screen
	$0
	
	Specify Serial, prints to screen
	$0 -s 4H632JhQXZ
	
	Specify Output format to Plist and save in specified output
	$0 -f plist -o /Library/Admin/

EOF
}

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


outputPlist() {
	PlistLocal="${Output}/appwarranty.plist"
	# Create plist for output
	# rm "${PlistLocal}" # Probably Unnecessary
	if [[ ! -e "${PlistLocal}" ]]; then
		AddPlistString warrantyscript version1 "${PlistLocal}"
		for i in purchasedate warrantyexpires warrantystatus modeltype asd serialnumber
		do
		AddPlistString $i unknown "${PlistLocal}"
		done
	fi
	# Write data to plist
	SetPlistString serialnumber "${SerialNumber}" "${PlistLocal}"
	SetPlistString purchasedate "${PurchaseDate}" "${PlistLocal}"
	SetPlistString warrantyexpires "${WarrantyExpires}" "${PlistLocal}"
	SetPlistString warrantystatus "${WarrantyStatus}" "${PlistLocal}"
	SetPlistString modeltype "${ModelType}" "${PlistLocal}"
	SetPlistString asd "${AsdVers}" "${PlistLocal}"
}

outputCSV() {
	# Csv output
	# Serial#, PurchaseDate, WarrantyExpires, WarrantyStatus, ModelType, AsdVers
	FixModel=`echo ${ModelType} |tr -d ','`
	echo "${SerialNumber}, ${PurchaseDate}, ${WarrantyExpires}, ${WarrantyStatus}, ${FixModel}, ${AsdVers}" >> "${Output}/warrantyoutput.csv"
}

outputSTDOUT() {
	# Write data to STDOUT
	echo "$(date) ... Checking warranty status"
	echo "Serial Number    ==  ${SerialNumber}"
	echo "PurchaseDate     ==  ${PurchaseDate}"
	echo "WarrantyExpires  ==  ${WarrantyExpires}"
	echo "WarrantyStatus   ==  ${WarrantyStatus}"
	echo "ModelType        ==  ${ModelType}"
	echo "ASD              ==  ${AsdVers}"
}

processCSV() {

for i in `cat "${1}"`; do

SerialNumber="${i}"

checkStatus
# [[ -n "${SerialNumber}" ]] && WarrantyInfo=`curl -k -s "https://selfsolve.apple.com/warrantyChecker.do?sn=${SerialNumber}&country=USA" | awk '{gsub(/\",\"/,"\n");print}' | awk '{gsub(/\":\"/,":");print}' | sed s/\"\}\)// > ${WarrantyTempFile}`
# 
# echo "$(date) ... Checking warranty status"
# InvalidSerial=`grep "wc.check.err.usr.pd04.invalidserialnumber" "${WarrantyTempFile}"`
# 
# if [[ -e "${WarrantyTempFile}" && -z "${InvalidSerial}" ]] ; then
# 	echo "Serial Number    ==  ${SerialNumber}"
# 
# 	PurchaseDate=`GetWarrantyValue PURCHASE_DATE`
# 	WarrantyExpires=`GetWarrantyValue HW_END_DATE`
# 	WarrantyStatus=`GetWarrantyStatus HW_SUPPORT_COV_SHORT`
# 	ModelType=`GetModelValue PROD_DESC`
# 	AsdVers=`GetAsdVers "${ModelType}"`
	FixModel=`echo ${ModelType} |tr -d ','`
	# Csv output
	# Serial#, PurchaseDate, WarrantyExpires, WarrantyStatus, ModelType, AsdVers
	echo "${SerialNumber}, ${PurchaseDate}, ${WarrantyExpires}, ${WarrantyStatus}, ${FixModel}, ${AsdVers}" >> "${Output}/bulkwarrantyoutput.csv"
	
# else
# 	if [[ -z "${SerialNumber}" ]]; then 
# 		echo "     No serial number was found."
# 		SetPlistString warrantystatus "Serial Not Found: ${SerialNumber}" "${PlistLocal}"
# 	fi
# 	if [[ -n "${InvalidSerial}" ]]; then
# 		echo "     Warranty information was not found for ${SerialNumber}."
# 		SetPlistString warrantystatus "Serial Invalid: ${SerialNumber}" "${PlistLocal}"
# 	fi
# fi

done
exit 0

}


checkStatus() {
	
echo "Checking ${SerialNumber}"

[[ -n "${SerialNumber}" ]] && WarrantyInfo=`curl -k -s "https://selfsolve.apple.com/warrantyChecker.do?sn=${SerialNumber}&country=USA" | awk '{gsub(/\",\"/,"\n");print}' | awk '{gsub(/\":\"/,":");print}' | sed s/\"\}\)// > ${WarrantyTempFile}`

InvalidSerial=`grep 'invalidserialnumber\|productdoesnotexist' "${WarrantyTempFile}"`

if [[ -n "${InvalidSerial}" ]]; then
	# echo " ERROR:    Warranty information was not found for ${SerialNumber}. ${InvalidSerial}"
	WarrantyStatus="Serial Invalid: ${SerialNumber}. ${InvalidSerial}"
fi
	
if [[ -z "${SerialNumber}" ]]; then 
	# echo " ERROR:    No serial number was found."
	WarrantyStatus="Serial Missing: ${SerialNumber}. ${InvalidSerial}"
fi

if [[ -e "${WarrantyTempFile}" && -z "${InvalidSerial}" ]] ; then

	PurchaseDate=`GetWarrantyValue PURCHASE_DATE`
	WarrantyExpires=`GetWarrantyValue HW_END_DATE`
	WarrantyStatus=`GetWarrantyStatus HW_SUPPORT_COV_SHORT`
	ModelType=`GetModelValue PROD_DESC`
	if [[ `echo ${ModelType}|grep 'OBS'` ]]; 
	then ModelType=`echo ${ModelType}|sed s/"OBS,"//`
	fi
	AsdVers=`GetAsdVers "${ModelType}"`	
fi

}

PrintData()
{
# echo "You have chosen: ${Format}"
case $Format in
	csv)
	outputCSV
	;;
	plist)
	outputPlist
	;;
	stdout)
	outputSTDOUT
	;;
esac
}

###################
##  APPLICATION  ##
###################

# Get serial
# Get csv
# Get output options
# Options:
# 			csv
# 			plist

while getopts s:c:o:f: opt; do
	case "$opt" in
		s) SerialNumber="$OPTARG";;
		c) SerialCSV="$OPTARG";;
		o) Output="$OPTARG";;
		f) Format="$OPTARG";;
		\?)
			help
			exit 0;;
	esac
done
shift `expr $OPTIND - 1`

curl -k -s https://raw.github.com/rustymyers/warranty/master/asdcheck -o ${AsdCheck} > /dev/null 2>&1

# No command line variables. Use internal serial and run checks
if [[ -z "$SerialNumber" ]]; then
	# Internal Serial Number
	SerialNumber=`system_profiler SPHardwareDataType | grep "Serial Number" | grep -v "tray" |  awk -F ': ' {'print $2'} 2>/dev/null`
fi

if [[ -z "$SerialCSV" ]]; then
checkStatus
PrintData
else
processCSV "${SerialCSV}"
fi

exit 0
