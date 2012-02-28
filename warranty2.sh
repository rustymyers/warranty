#!/bin/bash
# warranty.sh
# Description: looks up Apple warranty info for 
# this computer, or one specified by serial number 

# Based on a script by Scott Russell, IT Support Engineer, 
# University of Notre Dame
# Edited to add the ASD Versions by Joseph Chilcote
# Re-wrote by Rusty Myers for csv processing, plist and csv output.
# DSProperties output and HW_END_DATE error fix by Nate Walck.
# Days since DOP and Days remaining added by n8felton (02/09/2012)
# SPX output format added by n8felton (02/27/2012)
#
# Last Edited 02/27/2012


###############
##  GLOBALS  ##
###############

# make sure you use a full path
WarrantyTempFile="/tmp/warranty.$(date +%s).txt"
AsdCheck="/tmp/asdcheck.$(date +%s).txt"
PlistBuddy="/usr/libexec/PlistBuddy"
Output="."
CSVOutput="warranty.csv"
PlistOutput="warranty.plist"
SPXOutput="warranty.spx"
Format="stdout"
Version="3"


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
	-f [csv|plist|spx|DSProperties] = FORMAT output file to csv, plist, spx, or DeployStudio format.
	-o [/path/to/] = OUTPUT. Do not include filename. Default is the current working directory.
	-n <filename>[.plist|.csv|.spx] = Speficiy output filename. Ensure you use the appropriate extension for your output.
	
Defaults:
	WarrantyTempFile="${WarrantyTempFile}"
	AsdCheck="${AsdCheck}"
	Output="${Output}"
	Format="${Format}"

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

	Print the output during DeployStudio workflow to enter into custom properties.
	http://www.deploystudio.com/News/Entries/2011/7/20_DeployStudio_Server_1.0rc128.html
	$0 -f DSProperties
	
	Generate a system profile report to opene and/or merged with another report.
	$0 -f spx
	
	/usr/sbin/system_profiler -xml > firstreport.spx
	${PlistBuddy} -c "Merge warranty.spx" firstreport.spx

EOF
}

AddPlistString()
{
	# $1 is key name $2 is key value $3 plist location
	# example: AddPlistString warranty_script version1 /Library/ETC/appwarranty.plist
	${PlistBuddy} -c "add :"${1}" string \"${2}\"" "${3}"
}

SetPlistString()
{
	# $1 is key name $2 is key value $3 plist location
	# example: SetPlistString warranty_script version2 /Library/ETC/appwarranty.plist
	${PlistBuddy} -c "set :"${1}" \"${2}\"" "${3}"
}

GetWarrantyValue()
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
		AddPlistString warrantyscriptversion "${Version}" "${PlistLocal}" > /dev/null 2>&1
		for i in purchasedate warrantyexpires warrantystatus modeltype asd serialnumber currentdate daysremaining dayssincedop
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
	SetPlistString daysremaining "${DaysRemaining}" "${PlistLocal}"
	SetPlistString dayssincedop "${DaysSinceDOP}" "${PlistLocal}"
	SetPlistString currentdate $(date "+%m/%d/%Y") "${PlistLocal}"
}

outputCSV() {
	# Csv output
	# Serial#, PurchaseDate, DaysSinceDOP, WarrantyExpires, DaysRemaining, WarrantyStatus, ModelType, AsdVers
	FixModel=$(echo ${ModelType} |tr -d ',')
	echo "${SerialNumber}, ${PurchaseDate}, ${DaysSinceDOP}, ${WarrantyExpires}, ${DaysRemaining}, ${WarrantyStatus}, ${FixModel}, ${AsdVers}" >> "${Output}/${CSVOutput}"
}

outputSTDOUT() {
	# Write data to STDOUT
	echo "$(date) ... Checking warranty status"
	echo "Serial Number       ==  ${SerialNumber}"
	echo "PurchaseDate        ==  ${PurchaseDate}"
	echo "Days Since Purchase ==  ${DaysSinceDOP}"
	echo "WarrantyExpires     ==  ${WarrantyExpires}"
	echo "Days Remaining      ==  ${DaysRemaining}"
	echo "WarrantyStatus      ==  ${WarrantyStatus}"
	echo "ModelType           ==  ${ModelType}"
	echo "ASD                 ==  ${AsdVers}"
}

outputDSProperties() {
	#Write data to DeployStudio Properties
	echo "RuntimeSetCustomProperty: SERIAL_NUMBER=${SerialNumber}"
	# //-/ removes the dashes from the Purchase date.  Useful for conditional statements.
	echo "RuntimeSetCustomProperty: PURCHASE_DATE=${PurchaseDate//-/}"
	echo "RuntimeSetCustomProperty: DAYS_SINCE_DOP=${DaysSinceDOP}"	
	echo "RuntimeSetCustomProperty: WARRANTY_EXPIRES=${WarrantyExpires}"
	echo "RuntimeSetCustomProperty: DAYS_REMAINING=${DaysRemaining}"
	echo "RuntimeSetCustomProperty: WARRANTY_STATUS=${WarrantyStatus}"
	echo "RuntimeSetCustomProperty: MODEL_TYPE=${ModelType}"
	echo "RuntimeSetCustomProperty: ASD=${AsdVers}"
	#A timestamp of the last time the information was polled for the "Days" information
	echo "RuntimeSetCustomProperty: LAST_POLL=$(date +%Y-%m-%d)"	
}

outputSPX() {
	SPXOutput=${Output}/${SPXOutput}
(	
cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
</array>
</plist>
EOF
) > ${SPXOutput}

	${PlistBuddy} -c "Add 0:_dataType string Warranty" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_parentDataType string SPHardwareDataType" ${SPXOutput}	
	${PlistBuddy} -c "Add 0:_items array" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_items:0:_name string Warranty" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_items:0:Model string ${ModelType}" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_items:0:Serial\ Number string ${SerialNumber}" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_items:0:Purchase\ Date string ${PurchaseDate}" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_items:0:Warranty\ Expires string ${WarrantyExpires}" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_items:0:Warranty\ Status string ${WarrantyStatus}" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_items:0:ASD string ${AsdVers}" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_properties:Model:_order string 1" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_properties:Serial\ Number:_order string 2" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_properties:Purchase\ Date:_order string 3" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_properties:Warranty\ Expires:_order string 4" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_properties:Warranty\ Status:_order string 5" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_properties:ASD:_order string 6" ${SPXOutput}
}

processCSV() {

for i in $(cat "${1}"); do

SerialNumber="${i}"
checkStatus
outputCSV
sleep 5
done
exit 0

}

checkStatus() {

WarrantyURL="https://selfsolve.apple.com/warrantyChecker.do?sn=${SerialNumber}&country=USA"

[[ -n "${SerialNumber}" ]] && WarrantyInfo=$(curl -k -s $WarrantyURL | awk '{gsub(/\",\"/,"\n");print}' | awk '{gsub(/\":\"/,":");print}' | sed s/\"\}\)// > ${WarrantyTempFile})

#cat ${WarrantyTempFile}

InvalidSerial=$(grep 'invalidserialnumber\|productdoesnotexist' "${WarrantyTempFile}")

if [[ -n "${InvalidSerial}" ]]; then
	WarrantyStatus="Serial Invalid: ${SerialNumber}. ${InvalidSerial}"
fi
	
if [[ -z "${SerialNumber}" ]]; then 
	WarrantyStatus="Serial Missing: ${SerialNumber}. ${InvalidSerial}"
fi



if [[ -e "${WarrantyTempFile}" && -z "${InvalidSerial}" ]] ; then

	PurchaseDate=$(GetWarrantyValue PURCHASE_DATE)
	WarrantyStatus=$(GetWarrantyValue HW_SUPPORT_COV_SHORT)
	WarrantyExpires=$(GetWarrantyValue HW_END_DATE)
	if [[ -n "$WarrantyExpires" ]]; then
		WarrantyExpires=$(GetWarrantyValue HW_END_DATE|/bin/date -jf "%B %d, %Y" "${WarrantyExpires}" +"%Y-%m-%d") > /dev/null 2>&1 ## corrects Apple's change to "Month Day, Year" format for HW_END_DATE	
	else
		WarrantyExpires="${WarrantyStatus}"
	fi
	ModelType=$(GetModelValue PROD_DESC)
	# HW_COVERAGE_DESC
	
	# Remove the "OSB" from the beginning of ModelType
	if [[ $(echo ${ModelType}|grep 'OBS') ]]; 
		then ModelType=$(echo ${ModelType}|sed s/"OBS,"//)
	fi
	AsdVers=$(GetAsdVers "${ModelType}")
	
	#Days since purchase
	DaysSinceDOP=$(GetWarrantyValue NUM_DAYS_SINCE_DOP)
	
	#Days remaining
	DaysRemaining=$(GetWarrantyValue DAYS_REM_IN_COV)
	
	rm "${WarrantyTempFile}"
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
	spx)
	outputSPX
	;;
esac
}

FixDateYYYYMMDD()
{
	echo "${1}" | awk -F '-' {'print $2"/"$3"/"$1'}
}

###################
##  APPLICATION  ##
###################

# Get serial number, csv file
# Get output options: csv, plist

while getopts s:b:o:f:n:dh opt; do
	case "$opt" in
		s) SerialNumber="$OPTARG";;
		b) SerialCSV="$OPTARG";;
		o) Output="$OPTARG";;
		f) Format="$OPTARG";;
		n) OutputName="$OPTARG";;
		d) FixDate=1;;
		h) help
			exit 0;;
		\?)
			help
			exit 0;;
	esac
done
shift $(expr $OPTIND - 1)

curl -k -s https://raw.github.com/rustymyers/warranty/master/asdcheck -o ${AsdCheck} > /dev/null 2>&1

# No command line variables. Use internal serial and run checks
if [[ -z "$SerialNumber" ]]; then
	SerialNumber=$(system_profiler SPHardwareDataType | grep "Serial Number" | grep -v "tray" |  awk -F ': ' {'print $2'} 2>/dev/null)
fi

if [ "${OutputName}" ]; then
	CSVOutput="${OutputName}"
	PlistOutput="${OutputName}"
	SPXOutput="${OutputName}"
fi

if [[ -z "$SerialCSV" ]]; then
checkStatus
PrintData
else
processCSV "${SerialCSV}"
fi

rm "${AsdCheck}"

exit 0
