#!/bin/bash
# warranty.sh
# Description: looks up Apple warranty info for 
# this computer, or one specified by serial number 

# Based on a script by Scott Russell, IT Support Engineer, 
# University of Notre Dame
# http://www.nd.edu/~srussel2/macintosh/bash/warranty.txt
# Edited to add the ASD Versions by Joseph Chilcote
# Re-wrote by Rusty Myers for csv processing, plist and csv output.
# Edited 08/10/2011


###############
##  GLOBALS  ##
###############

# make sure you use a full path
WarrantyTempFile="/tmp/warranty.txt"
AsdCheck="/tmp/asdcheck.txt"
Output="."
CSVOutput="warranty.csv"
PlistOutput="warranty.plist"
Format="stdout"
Version="2"


#################
##  FUNCTIONS  ##
#################

help()
{
cat<<EOF

Input:
	no flags = use this computers serial
	-b = loop through BULK csv file
		 processing a csv file will only output to a 
		 csv file. other output formats will be ignored
	-s = specify SERIAL number

Output:
	-f [csv|plist] = FORMAT output file to csv or plist.
	-o [/path/to/] = OUTPUT. Don't not include filename. Default is same directory as script.	
	-n [warranty.plist|.csv] = Speficiy output file NAME. Ensure you use the appropriate extension for your output.
	
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
	
	Specify Output format to Plist and save in specified output and a custom name
	$0 -f plist -o ~/Desktop/ -n myserials.plist
	
	Process list of serials and output to custom location and custom name
	$0 -b serials.csv -o ~/Desktop/ -n myserials.csv

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
	grep "${1}:" ${AsdCheck} | awk -F':' {'print $2'}
}


outputPlist() {
	PlistLocal="${Output}/${PlistOutput}"
	# Create plist for output
	rm "${PlistLocal}" > /dev/null 2>&1 # Probably Unnecessary, Just being Safe
	if [[ ! -e "${PlistLocal}" ]]; then
		AddPlistString warrantyscript "${Version}" "${PlistLocal}" > /dev/null 2>&1
		for i in purchasedate warrantyexpires warrantystatus modeltype asd serialnumber
		do
		AddPlistString $i unknown "${PlistLocal}"
		done
	fi
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
	echo "${SerialNumber}, ${PurchaseDate}, ${WarrantyExpires}, ${WarrantyStatus}, ${FixModel}, ${AsdVers}" >> "${Output}/${CSVOutput}"
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

outputDSProperties() {
	#Write data to DeployStudio Properties
	echo "RuntimeSetCustomProperty: SerialNumber=${SerialNumber}"
	echo "RuntimeSetCustomProperty: PurchaseDate=${PurchaseDate}"
	echo "RuntimeSetCustomProperty: WarrantyExpires=${WarrantyExpires}
	echo "RuntimeSetCustomProperty: WarrantyStatus=${WarrantyStatus}"
	echo "RuntimeSetCustomProperty: ModelType=${ModelType}"
	echo "RuntimeSetCustomProperty: ASD=${AsdVers}"

processCSV() {

for i in `cat "${1}"`; do

SerialNumber="${i}"
checkStatus
outputCSV

done
exit 0

}


checkStatus() {

[[ -n "${SerialNumber}" ]] && WarrantyInfo=`curl -k -s "https://selfsolve.apple.com/warrantyChecker.do?sn=${SerialNumber}&country=USA" | awk '{gsub(/\",\"/,"\n");print}' | awk '{gsub(/\":\"/,":");print}' | sed s/\"\}\)// > ${WarrantyTempFile}`

InvalidSerial=`grep 'invalidserialnumber\|productdoesnotexist' "${WarrantyTempFile}"`

if [[ -n "${InvalidSerial}" ]]; then
	WarrantyStatus="Serial Invalid: ${SerialNumber}. ${InvalidSerial}"
fi
	
if [[ -z "${SerialNumber}" ]]; then 
	WarrantyStatus="Serial Missing: ${SerialNumber}. ${InvalidSerial}"
fi

if [[ -e "${WarrantyTempFile}" && -z "${InvalidSerial}" ]] ; then

	PurchaseDate=`GetWarrantyValue PURCHASE_DATE`
	WarrantyExpires=`GetWarrantyValue HW_END_DATE`
	WarrantyExpires=`GetWarrantyValue HW_END_DATE|/bin/date -jf "%B %d, %Y" "${WarrantyExpires}" +"%Y-%m-%d"` > /dev/null 2>&1 ## corrects Apple's change to "Month Day, Year" format for HW_END_DATE
	WarrantyStatus=`GetWarrantyStatus HW_SUPPORT_COV_SHORT`
	ModelType=`GetModelValue PROD_DESC`
	# Remove the "OSB" from the beginning of ModelType
	if [[ `echo ${ModelType}|grep 'OBS'` ]]; 
		then ModelType=`echo ${ModelType}|sed s/"OBS,"//`
	fi
	AsdVers=`GetAsdVers "${ModelType}"`	
fi

}

PrintData()
{
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
	DSProperties)
	outputDSProperties
	;;
esac
}

###################
##  APPLICATION  ##
###################

# Get serial number, csv file
# Get output options: csv, plist

while getopts s:b:o:f:n:h opt; do
	case "$opt" in
		s) SerialNumber="$OPTARG";;
		b) SerialCSV="$OPTARG";;
		o) Output="$OPTARG";;
		f) Format="$OPTARG";;
		n) OutputName="$OPTARG";;
		h) help
			exit 0;;
		\?)
			help
			exit 0;;
	esac
done
shift `expr $OPTIND - 1`

curl -k -s https://raw.github.com/rustymyers/warranty/master/asdcheck -o ${AsdCheck} > /dev/null 2>&1

# No command line variables. Use internal serial and run checks
if [[ -z "$SerialNumber" ]]; then
	SerialNumber=`system_profiler SPHardwareDataType | grep "Serial Number" | grep -v "tray" |  awk -F ': ' {'print $2'} 2>/dev/null`
fi

if [ "${OutputName}" ]; then
	CSVOutput="${OutputName}"
	PlistOutput="${OutputName}"
fi

if [[ -z "$SerialCSV" ]]; then
checkStatus
PrintData
else
processCSV "${SerialCSV}"
fi

exit 0
