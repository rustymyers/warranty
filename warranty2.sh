#!/bin/bash
# warranty.sh
# Description: looks up Apple warranty info for 
# this computer, or one specified by serial number 

# Based on a script by Scott Russell, IT Support Engineer, 
# University of Notre Dame
# http://www.nd.edu/~srussel2/macintosh/bash/warranty.txt
# Edited to add the ASD Versions by Joseph Chilcote
# Re-wrote by Rusty Myers for csv processing, plist and csv output.
# DSProperties output and HW_END_DATE error fix by Nate Walck.
# Days since DOP and Days remaining added by n8felton (02/09/2012)
# SPX output format added by n8felton (02/27/2012)
#
# Last Edited 02/27/2012
# Last Edited 05/11/2012
# Adding iPhone Support
# Fixing debugg and verbose flags
# Last Edited 2012/06/20
# Apple's update to the warranty site removed a few of the keys we pulled.
# Last Edited 06/14/2012
# Updating code for TEM Server at PSU


###############
##  GLOBALS  ##
###############

# make sure you use a full path
WarrantyTempFile="/tmp/warranty.$(date +%s).txt"
AsdCheck="/tmp/asdcheck.$(date +%s).txt"
PlistBuddy="/usr/libexec/PlistBuddy"
Output="/Library/Sysman" # No Trailing Slash
CSVOutput="warranty.csv"
PlistOutput="PSUWarranty.plist"
SPXOutput="warranty.spx"
Format="plist"
Version="5.1"
DEBUGG=		# Set to 1 to enable debugging ( Don't delete temp files )
VERBOSE=	# Set to 1 to enable bulk editing verboseness

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
	-o [/path/to/] = OUTPUT. Use Full Path. Do not include filename. Default is same directory as script.
	-n <filename>[.plist|.csv|.spx] = Speficiy output filename. Ensure you use the appropriate extension for your output.
	-v = Enable sexy verboseness	
	-k = Enable debugging (Don't delete temp files)

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

flags()
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
	-o [/path/to/] = OUTPUT. Use Full Path. Do not include filename. Default is same directory as script.
	-n <filename>[.plist|.csv|.spx] = Speficiy output filename. Ensure you use the appropriate extension for your output.
	-v = Enable sexy verboseness	
	-k = Enable debugging (Don't delete temp files)
	-h = Full help page (With Examples!)

Defaults:
	WarrantyTempFile="${WarrantyTempFile}"
	AsdCheck="${AsdCheck}"
	Output="${Output}"
	Format="${Format}"
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

FixDate()
{
	echo "${1}" | awk -F '-' {'print $2"/"$3"/"$1'}
}

outputPlist() {
	PlistLocal="${Output}/${PlistOutput}"
	# Create plist for output
	if [ "${VERBOSE}" ]; then 
		echo "Removing ${PlistLocal}"
	fi
	
	rm "${PlistLocal}" > /dev/null 2>&1 # Probably Unnecessary, Just being Safe
	
	if [[ ! -e "${PlistLocal}" ]]; then
		AddPlistString warrantyscriptversion "${Version}" "${PlistLocal}" > /dev/null 2>&1
		for i in  warrantyexpires warrantystatus modeltype asd serialnumber currentdate isaniphone iphonecarrier partdescript
		# for i in purchasedate warrantyexpires warrantystatus modeltype asd serialnumber currentdate daysremaining dayssincedop isaniphone iphonecarrier partdescript ## Apple Removed fields from warranty site

		do
		AddPlistString $i unknown "${PlistLocal}"
		done
	fi
	
	if [ "${VERBOSE}" ]; then 
		echo "Created ${PlistLocal}, adding fields"
	fi
	
	SetPlistString serialnumber "${SerialNumber}" "${PlistLocal}"
# 	SetPlistString purchasedate "${PurchaseDate}" "${PlistLocal}" ## Apple Removed from warranty site
	SetPlistString warrantyexpires "${WarrantyExpires}" "${PlistLocal}"
	SetPlistString warrantystatus "${WarrantyStatus}" "${PlistLocal}"
	SetPlistString modeltype "${ModelType}" "${PlistLocal}"
	SetPlistString asd "${AsdVers}" "${PlistLocal}"
# 	SetPlistString daysremaining "${DaysRemaining}" "${PlistLocal}" ## Apple Removed from warranty site
# 	SetPlistString dayssincedop "${DaysSinceDOP}" "${PlistLocal}" ## Apple Removed from warranty site
	SetPlistString currentdate $(date "+%m/%d/%Y") "${PlistLocal}"
	SetPlistString isaniphone "${IsAniPhone}" "${PlistLocal}"
	SetPlistString iphonecarrier "${iPhoneCarrier}" "${PlistLocal}"
	SetPlistString partdescript "${PartDescript}" "${PlistLocal}"
	
	if [ "${VERBOSE}" ]; then 
		echo "All fields added"
	fi
}

outputCSV() {
	
	if [ "${VERBOSE}" ]; then 
		echo "Creating csv output"
	fi
	
	# CSV Headers
	# "SerialNumber, WarrantyExpires, WarrantyStatus, FixModel, AsdVers, IsAniPhone, iPhoneCarrier, PartDescript" 
	FixModel=$(echo ${ModelType} |tr -d ',')
#	echo "${SerialNumber}, ${PurchaseDate}, ${DaysSinceDOP}, ${WarrantyExpires}, ${DaysRemaining}, ${WarrantyStatus}, ${FixModel}, ${AsdVers}, ${IsAniPhone}, ${iPhoneCarrier}, ${PartDescript}" >> "${Output}/${CSVOutput}" ## Apple Removed fields from warranty site
	echo "${SerialNumber}, ${WarrantyExpires}, ${WarrantyStatus}, ${FixModel}, ${AsdVers}, ${IsAniPhone}, ${iPhoneCarrier}, ${PartDescript}" >> "${Output}/${CSVOutput}"
	
}

outputSTDOUT() {
	# Write data to STDOUT
	echo "$(date) ... Checking warranty status"
	echo "Serial Number       ==  ${SerialNumber}"
	# echo "PurchaseDate        ==  ${PurchaseDate}"
	# echo "Days Since Purchase ==  ${DaysSinceDOP}"
	echo "WarrantyExpires     ==  ${WarrantyExpires}"
	# echo "Days Remaining      ==  ${DaysRemaining}"
	echo "WarrantyStatus      ==  ${WarrantyStatus}"
	echo "ModelType           ==  ${ModelType}"
	echo "ASD                 ==  ${AsdVers}"
	echo "IsAniPhone          ==  ${IsAniPhone}"
	echo "iPhoneCarrier       ==  ${iPhoneCarrier}"
	echo "PartDescript        ==  ${PartDescript}"
}

outputDSProperties() {
	#Write data to DeployStudio Properties
	echo "RuntimeSetCustomProperty: SERIAL_NUMBER=${SerialNumber}"
	# //-/ removes the dashes from the Purchase date.  Useful for conditional statements.
# 	echo "RuntimeSetCustomProperty: PURCHASE_DATE=${PurchaseDate//-/}" ## Apple Removed from warranty site
# 	echo "RuntimeSetCustomProperty: DAYS_SINCE_DOP=${DaysSinceDOP}"	## Apple Removed from warranty site
	echo "RuntimeSetCustomProperty: WARRANTY_EXPIRES=${WarrantyExpires}"
# 	echo "RuntimeSetCustomProperty: DAYS_REMAINING=${DaysRemaining}" ## Apple Removed from warranty site
	echo "RuntimeSetCustomProperty: WARRANTY_STATUS=${WarrantyStatus}"
	echo "RuntimeSetCustomProperty: MODEL_TYPE=${ModelType}"
	echo "RuntimeSetCustomProperty: ASD=${AsdVers}"
	echo "RuntimeSetCustomProperty: IsAniPhone=${IsAniPhone}"
	echo "RuntimeSetCustomProperty: iPhoneCarrier=${iPhoneCarrier}"
	echo "RuntimeSetCustomProperty: PartDescript=${PartDescript}"
	#A timestamp of the last time the information was polled for the "Days" information
	echo "RuntimeSetCustomProperty: LAST_POLL=$(date +%Y-%m-%d)"	
}

outputSPX() {

	SPXOutput=${Output}/${SPXOutput}
	if [ "${VERBOSE}" ]; then 
		echo "Outputing to SPX format."
	fi

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

	if [ "${VERBOSE}" ]; then 
		echo "Adding Fields to SPX file."
	fi

	${PlistBuddy} -c "Add 0:_dataType string Warranty" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_parentDataType string SPHardwareDataType" ${SPXOutput}	
	${PlistBuddy} -c "Add 0:_items array" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_items:0:_name string Warranty" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_items:0:Model string ${ModelType}" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_items:0:Serial\ Number string ${SerialNumber}" ${SPXOutput}
# 	${PlistBuddy} -c "Add 0:_items:0:Purchase\ Date string ${PurchaseDate}" ${SPXOutput} ## Apple Removed from warranty site
	${PlistBuddy} -c "Add 0:_items:0:Warranty\ Expires string ${WarrantyExpires}" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_items:0:Warranty\ Status string ${WarrantyStatus}" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_items:0:ASD string ${AsdVers}" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_items:0:IsAniPhone string ${IsAniPhone}" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_items:0:iPhoneCarrier string ${iPhoneCarrier}" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_items:0:PartDescript string ${PartDescript}" ${SPXOutput}	
	${PlistBuddy} -c "Add 0:_properties:Model:_order string 1" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_properties:Serial\ Number:_order string 2" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_properties:Purchase\ Date:_order string 3" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_properties:Warranty\ Expires:_order string 4" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_properties:Warranty\ Status:_order string 5" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_properties:ASD:_order string 6" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_properties:IsAniPhone:_order string 7" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_properties:iPhoneCarrier:_order string 8" ${SPXOutput}
	${PlistBuddy} -c "Add 0:_properties:PartDescript:_order string 9" ${SPXOutput}

	if [ "${VERBOSE}" ]; then 
		echo "Added All Fields to SPX file."
	fi	
}

processCSV() {
if [ "${VERBOSE}" ]; then 
	echo "Creating ${Output}/${CSVOutput}"
fi

# Echo headings into CSV file.
if [ "${VERBOSE}" ]; then 
	echo "Adding CSV headers."
fi
echo "SerialNumber, WarrantyExpires, WarrantyStatus, FixModel, AsdVers, IsAniPhone, iPhoneCarrier, PartDescript" >> "${Output}/${CSVOutput}"
# echo "SerialNumber, PurchaseDate, DaysSinceDOP, WarrantyExpires, DaysRemaining, WarrantyStatus, FixModel, AsdVers, IsAniPhone, iPhoneCarrier, PartDescript" >> "${Output}/${CSVOutput}" ## Apple Removed from warranty site

for i in $(cat "${1}"); do

if [ "${VERBOSE}" ]; then 
	echo "Checking ${i}"
fi

SerialNumber="${i}"
checkStatus
outputCSV
sleep 5
done

}

checkStatus() {

WarrantyURL="https://selfsolve.apple.com/warrantyChecker.do?sn=${SerialNumber}&country=USA"

if [ "${VERBOSE}" ]; then 
	echo "Checking Serial: ${SerialNumber} Warranty Status from URL ${WarrantyURL}"
fi

[[ -n "${SerialNumber}" ]] && WarrantyInfo=$(curl -k -s $WarrantyURL | awk '{gsub(/\",\"/,"\n");print}' | awk '{gsub(/\":\"/,":");print}' | sed s/\"\}\)// > ${WarrantyTempFile})

#cat ${WarrantyTempFile}

InvalidSerial=$(grep 'invalidserialnumber\|productdoesnotexist' "${WarrantyTempFile}")

if [[ -n "${InvalidSerial}" ]]; then
	WarrantyStatus="Serial Invalid: ${SerialNumber}. ${InvalidSerial}"
	if [ "${VERBOSE}" ]; then 
		echo "Invalid Serial Number"
	fi
fi
	
if [[ -z "${SerialNumber}" ]]; then 
	WarrantyStatus="Serial Missing: ${SerialNumber}. ${InvalidSerial}"
	if [ "${VERBOSE}" ]; then 
		echo "Serial Number Missing"
	fi
fi


if [[ -e "${WarrantyTempFile}" && -z "${InvalidSerial}" ]] ; then

	if [ "${VERBOSE}" ]; then 
		echo "Scanning file for specified fields."
	fi

	# PurchaseDate=$(GetWarrantyValue PURCHASE_DATE) ## Apple Removed from warranty site
	# PurchaseDate=$(/bin/date -jf "%Y-%m-%d" "${PurchaseDate}" +"%m/%d/%Y") # Change date format.

	WarrantyStatus=$(GetWarrantyValue HW_SUPPORT_COV_SHORT)
	WarrantyExpires=$(GetWarrantyValue HW_END_DATE) #| /bin/date -jf "%B %d, %Y" "${WarrantyExpires}" +"%Y-%m-%d")
	# If the HW_END_DATE is found, fix the date formate. Otherwise set it to the WarrantyStatus.
	if [[ -n "$WarrantyExpires" ]]; then
		WarrantyExpires=$(GetWarrantyValue HW_END_DATE|/bin/date -jf "%B %d, %Y" "${WarrantyExpires}" +"%m/%d/%Y") > /dev/null 2>&1 ## corrects Apple's change to "Month Day, Year" format for HW_END_DATE	
	else
		WarrantyExpires="${WarrantyStatus}"
	fi
	ModelType=$(GetModelValue PROD_DESCR)
	# HW_COVERAGE_DESC
	
	# Remove the "OSB" from the beginning of ModelType
	if [[ $(echo ${ModelType}|grep 'OBS') ]]; 
		then ModelType=$(echo ${ModelType}|sed s/"OBS,"//)
	fi
	
	# Retrieve ASD version based on ModelType
	AsdVers=$(GetAsdVers "${ModelType}")
	
	#Days since purchase
	#DaysSinceDOP=$(GetWarrantyValue NUM_DAYS_SINCE_DOP) ## Apple Removed from warranty site
	
	#Days remaining
	#DaysRemaining=$(GetWarrantyValue DAYS_REM_IN_COV) ## Apple Removed from warranty site
	
	#Is serial an iPhone?
	IsAniPhone=$(GetWarrantyValue IS_IPHONE)
	
	#iPhone Carrier?
	iPhoneCarrier=$(GetWarrantyValue CARRIER)
	
	#iPhone Part Description
	PartDescript=$(GetWarrantyValue PART_DESCR)
	
	# Hardware Support Link
	#HWSupport=$(GetWarrantyValue HW_SUPPORT_LINK)
	
	if [ "${VERBOSE}" ]; then 
		echo "All Fields Found."
	fi
	# Delete temp files if NODEBUGG is 1
	if [ ! "${DEBUGG}" ]; then
		rm "${WarrantyTempFile}"
		if [ "${VERBOSE}" ]; then 
			echo "Removing Temp Warranty File"
		fi
	fi
fi

}

PrintData()
{
case $Format in
	csv)
	if [ "${VERBOSE}" ]; then 
	echo "Adding CSV Headers."
	fi
	echo "SerialNumber, PurchaseDate, DaysSinceDOP, WarrantyExpires, DaysRemaining, WarrantyStatus, FixModel, AsdVers, IsAniPhone, iPhoneCarrier, PartDescript" >> "${Output}/${CSVOutput}"
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
# You should be exporting this to a static place you can pull reports from.

while getopts s:b:o:f:n:dvkh opt; do
	case "$opt" in
		s) SerialNumber="$OPTARG";;
		b) SerialCSV="$OPTARG";;
		o) Output="$OPTARG";;
		f) Format="$OPTARG";;
		n) OutputName="$OPTARG";;
		d) FixDate=1;;
		v) VERBOSE=1;;
		k) DEBUGG=1;;
		h) help
			exit 0;;
		\?)
			flags
			exit 0;;
	esac
done
shift $(expr $OPTIND - 1)

# Make output dir if specified
if [ "${Output}" ]; then
	mkdir -p "${Output}"
fi

## Add Timeout so this curl doesn't try forever when GitHub raw is down. Cache a local copy? Try alternate forks?
## Fail to unknown ASD after 5 seconds? Don't take too long, you'll get the numbers eventually. 
if [ "${VERBOSE}" ]; then 
	echo "Downloading ASD file."
fi
curl -k -s https://raw.github.com/rustymyers/warranty/master/asdcheck -o ${AsdCheck} #> /dev/null 2>&1

# No command line variables. Use internal serial and run checks
if [[ -z "$SerialNumber" ]]; then
	if [ "${VERBOSE}" ]; then 
		echo "No Serial's provided, using local computers"
	fi
	SerialNumber=$(system_profiler SPHardwareDataType | grep "Serial Number" | grep -v "tray" |  awk -F ': ' {'print $2'} 2>/dev/null)
fi

if [ "${OutputName}" ]; then
	if [ "${VERBOSE}" ]; then 
		echo "Changing output name to ${OutputName}"
	fi
	CSVOutput="${OutputName}"
	PlistOutput="${OutputName}"
	SPXOutput="${OutputName}"
fi

if [[ -z "$SerialCSV" ]]; then

checkStatus
PrintData
else
if [ "${VERBOSE}" ]; then 
	echo "Processing CSV file."
fi
processCSV "${SerialCSV}"
fi

# Delete temp files if NODEBUGG is 1
if [ ! "${DEBUGG}" ]; then
	rm "${AsdCheck}"
		if [ "${VERBOSE}" ]; then 
			echo "Removing Temp ASD File"
		fi
fi

exit 0
