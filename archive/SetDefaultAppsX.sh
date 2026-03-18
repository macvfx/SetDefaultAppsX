#!/bin/zsh
#
# SetDefaultAppsX.sh
#
# Version: 2.1
# Modified: 2025-12-16
# Changes: Added automatic utiluti download and installation with signature verification
#
# Original by: Scott Kendall
# Written: 12/11/2025
# Last updated: 12/16/2025
#
# Script Purpose: set the default UTI applications (mailto, url, http, etc)
#
# 1.0 - Initial
# 2.0 - Removed JAMF dependencies, added standalone swiftDialog installer
# 2.1 - Added automatic utiluti download and installation with Team ID verification

######################################################################################################
#
# Global "Common" variables
#
######################################################################################################
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
SCRIPT_NAME="SetDefaultAppsX"
LOGGED_IN_USER=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
USER_DIR=$( dscl . -read /Users/${LOGGED_IN_USER} NFSHomeDirectory | awk '{ print $2 }' )
USER_UID=$(id -u "$LOGGED_IN_USER")

# Detect CPU type - Use sysctl (most reliable method)
# sysctl works in all contexts and doesn't require full disk access
MAC_CPU=$( /usr/sbin/sysctl -n machdep.cpu.brand_string 2>/dev/null )

# If sysctl failed, fall back to uname detection
if [[ -z "$MAC_CPU" ]]; then
    if [[ "$(/usr/bin/uname -m)" == "arm64" ]]; then
        MAC_CPU="Apple Silicon"
    else
        MAC_CPU="Intel"
    fi
fi

# Get RAM using sysctl (more reliable than system_profiler)
MAC_RAM=$( /usr/sbin/sysctl -n hw.memsize 2>/dev/null | /usr/bin/awk '{printf "%.0f GB", $1/1024/1024/1024}' )
[[ -z "$MAC_RAM" ]] && MAC_RAM="Unknown"
FREE_DISK_SPACE=$(($( /usr/sbin/diskutil info / | /usr/bin/grep "Free Space" | /usr/bin/awk '{print $6}' | /usr/bin/cut -c 2- ) / 1024 / 1024 / 1024 ))

# Export variables to ensure they're available in functions
export MAC_CPU
export MAC_RAM
export FREE_DISK_SPACE

ICON_FILES="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/"
UTI_COMMAND="/usr/local/bin/utiluti"

# Swift Dialog version requirements

SW_DIALOG="/usr/local/bin/dialog"
MIN_SD_REQUIRED_VERSION="2.5.0"
[[ -e "${SW_DIALOG}" ]] && SD_VERSION=$( ${SW_DIALOG} --version) || SD_VERSION="0.0.0"

SD_DIALOG_GREETING=$((){print Good ${argv[2+($1>11)+($1>18)]}} ${(%):-%D{%H}} morning afternoon evening)

# Make some temp files

JSON_DIALOG_BLOB=$(mktemp /var/tmp/ExtractBundleIDs.XXXXX)
DIALOG_COMMAND_FILE=$(mktemp /var/tmp/ExtractBundleIDs.XXXXX)
chmod 666 $JSON_DIALOG_BLOB
chmod 666 $DIALOG_COMMAND_FILE

###################################################
#
# App Specific variables (Feel free to change these)
#
###################################################

# See if there is a "defaults" file...if so, read in the contents
DEFAULTS_DIR="/Library/Managed Preferences/com.setdefaultappsx.defaults.plist"
if [[ -e $DEFAULTS_DIR ]]; then
    echo "Found Defaults Files.  Reading in Info"
    SUPPORT_DIR=$(defaults read $DEFAULTS_DIR "SupportFiles")
    SD_BANNER_IMAGE=$SUPPORT_DIR$(defaults read $DEFAULTS_DIR "BannerImage")
    spacing=$(defaults read $DEFAULTS_DIR "BannerPadding")
else
    SUPPORT_DIR="/Library/Application Support/SetDefaultAppsX"
    SD_BANNER_IMAGE="${SUPPORT_DIR}/SupportFiles/SD_BannerImage.png"
    spacing=5 #5 spaces to accommodate for icon offset
fi
repeat $spacing BANNER_TEXT_PADDING+=" "

# Log files location

LOG_FILE="${SUPPORT_DIR}/logs/${SCRIPT_NAME}.log"

# Display items (banner / icon)

SD_WINDOW_TITLE="${BANNER_TEXT_PADDING}Default Apps Selection"
SD_ICON="/System/Applications/App Store.app"
# Use SF Symbol for overlay icon (xmark.circle for X symbol)
OVERLAY_ICON="SF=xmark.circle,weight=medium,colour1=#000000,colour2=#ffffff"

# Get user's first name from the logged in user
SD_FIRST_NAME="${(C)LOGGED_IN_USER%%.*}"

####################################################################################################
#
# Functions
#
####################################################################################################

function check_directory_structure ()
{
    # Check that the required directory structure exists
    # If /Library/Application Support is not accessible, fall back to /Users/Shared
    # Creates directories as needed without requiring sudo
    #
    # RETURN: None (updates SUPPORT_DIR and LOG_FILE variables if fallback is used)

	# Check if support directory exists
	if [[ ! -d "${SUPPORT_DIR}" ]]; then
		echo ""
		echo "========================================="
		echo "WARNING: Application Support directory not found"
		echo "========================================="
		echo ""
		echo "The directory ${SUPPORT_DIR} does not exist."
		echo "Falling back to /Users/Shared/SetDefaultAppsX"
		echo ""

		# Update to use /Users/Shared instead
		SUPPORT_DIR="/Users/Shared/SetDefaultAppsX"
		SD_BANNER_IMAGE="${SUPPORT_DIR}/SupportFiles/SD_BannerImage.png"
		LOG_FILE="${SUPPORT_DIR}/logs/${SCRIPT_NAME}.log"

		# Create the directory structure in /Users/Shared
		if [[ ! -d "${SUPPORT_DIR}" ]]; then
			/bin/mkdir -p "${SUPPORT_DIR}"
			/bin/chmod 755 "${SUPPORT_DIR}"
		fi

		echo "Using: ${SUPPORT_DIR}"
		echo "========================================="
		echo ""
	fi

	# Check if log directory exists and is writable
	LOG_DIR=${LOG_FILE%/*}
	if [[ ! -d "${LOG_DIR}" ]]; then
		# Create log directory
		/bin/mkdir -p "${LOG_DIR}"
		/bin/chmod 755 "${LOG_DIR}"
	fi

	# Create support files directory if it doesn't exist
	SUPPORT_FILES_DIR="${SUPPORT_DIR}/SupportFiles"
	if [[ ! -d "${SUPPORT_FILES_DIR}" ]]; then
		/bin/mkdir -p "${SUPPORT_FILES_DIR}"
		/bin/chmod 755 "${SUPPORT_FILES_DIR}"
	fi

	# Try to create log file if it doesn't exist
	if [[ ! -f "${LOG_FILE}" ]]; then
		/usr/bin/touch "${LOG_FILE}" 2>/dev/null
		if [[ $? -ne 0 ]]; then
			echo ""
			echo "========================================="
			echo "ERROR: Cannot create log file"
			echo "========================================="
			echo ""
			echo "Cannot create log file at ${LOG_FILE}"
			echo "This should not happen with /Users/Shared"
			echo "Please check your system permissions."
			echo ""
			echo "========================================="
			exit 1
		fi
		/bin/chmod 644 "${LOG_FILE}" 2>/dev/null
	fi
}

function logMe ()
{
    # Basic two pronged logging function that will log like this:
    #
    # 20231204 12:00:00: Some message here
    #
    # This function logs both to STDOUT/STDERR and a file
    # The log file is set by the $LOG_FILE variable.
    #
    # RETURN: None
    echo "$(/bin/date '+%Y-%m-%d %H:%M:%S'): ${1}" | tee -a "${LOG_FILE}" 1>&2
}

function install_swift_dialog ()
{
    # Install Swift Dialog from GitHub
    # Downloads the latest release and installs it
    #
    # RETURN: 0 on success, 1 on failure

    logMe "swiftDialog not installed, downloading and installing"

    expectedDialogTeamID="PWA5E9TQ59"

    logMe "Fetching latest swiftDialog release URL"
    LOCATION=$(/usr/bin/curl -s https://api.github.com/repos/bartreardon/swiftDialog/releases/latest | grep browser_download_url | grep .pkg | grep -v debug | awk '{ print $2 }' | sed 's/,$//' | sed 's/"//g')

    if [[ -z "$LOCATION" ]]; then
        logMe "ERROR: Failed to get swiftDialog download URL"
        return 1
    fi

    logMe "Download URL: $LOCATION"

    logMe "Downloading swiftDialog package"
    /usr/bin/curl -L "$LOCATION" -o /tmp/swiftDialog.pkg

    if [[ ! -f /tmp/swiftDialog.pkg ]]; then
        logMe "ERROR: Failed to download swiftDialog"
        return 1
    fi

    logMe "Verifying package signature"
    teamID=$(/usr/sbin/spctl -a -vv -t install "/tmp/swiftDialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')

    if [[ "$expectedDialogTeamID" = "$teamID" ]] || [[ "$expectedDialogTeamID" = "" ]]; then
        logMe "swiftDialog Team ID verification succeeded (TeamID: $teamID)"
        /usr/sbin/installer -pkg /tmp/swiftDialog.pkg -target /
    else
        logMe "ERROR: swiftDialog Team ID verification failed. Expected: $expectedDialogTeamID, Got: $teamID"
        /bin/rm /tmp/swiftDialog.pkg
        return 1
    fi

    logMe "Cleaning up swiftDialog.pkg"
    /bin/rm /tmp/swiftDialog.pkg

    # Update the version after installation
    [[ -e "${SW_DIALOG}" ]] && SD_VERSION=$( ${SW_DIALOG} --version) || SD_VERSION="0.0.0"

    return 0
}

function check_swift_dialog_install ()
{
    # Check to make sure that Swift Dialog is installed and functioning correctly
    # Will install process if missing or corrupted
    #
    # RETURN: None

    logMe "Ensuring that swiftDialog version is installed..."
    if [[ ! -x "${SW_DIALOG}" ]]; then
        logMe "Swift Dialog is missing or corrupted - Installing from GitHub"
        install_swift_dialog
        if [[ $? -ne 0 ]]; then
            logMe "ERROR: Failed to install swiftDialog"
            exit 1
        fi
    fi

    if ! is-at-least "${MIN_SD_REQUIRED_VERSION}" "${SD_VERSION}"; then
        logMe "Swift Dialog is outdated - Installing version '${MIN_SD_REQUIRED_VERSION}' from GitHub..."
        install_swift_dialog
        if [[ $? -ne 0 ]]; then
            logMe "ERROR: Failed to update swiftDialog"
            exit 1
        fi
    else
        logMe "Swift Dialog is currently running: ${SD_VERSION}"
    fi
}

function install_utiluti ()
{
    # Download and install utiluti from GitHub releases
    # Verifies package signature before installation
    #
    # RETURN: 0 on success, 1 on failure

    logMe "utiluti not installed, downloading and installing"

    expectedUtilitiTeamID="JME5BW3F3R"

    logMe "Fetching latest utiluti release URL"
    LOCATION=$(/usr/bin/curl -s https://api.github.com/repos/scriptingosx/utiluti/releases/latest | grep browser_download_url | grep .pkg | awk '{ print $2 }' | sed 's/,$//' | sed 's/"//g')

    if [[ -z "$LOCATION" ]]; then
        logMe "ERROR: Failed to get utiluti download URL"
        return 1
    fi

    logMe "Download URL: $LOCATION"

    logMe "Downloading utiluti package"
    /usr/bin/curl -L "$LOCATION" -o /tmp/utiluti.pkg

    if [[ ! -f /tmp/utiluti.pkg ]]; then
        logMe "ERROR: Failed to download utiluti"
        return 1
    fi

    logMe "Verifying package signature"
    teamID=$(/usr/sbin/spctl -a -vv -t install "/tmp/utiluti.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')

    if [[ "$expectedUtilitiTeamID" = "$teamID" ]] || [[ "$expectedUtilitiTeamID" = "" ]]; then
        logMe "utiluti Team ID verification succeeded (TeamID: $teamID)"
        /usr/sbin/installer -pkg /tmp/utiluti.pkg -target /
    else
        logMe "ERROR: utiluti Team ID verification failed. Expected: $expectedUtilitiTeamID, Got: $teamID"
        /bin/rm /tmp/utiluti.pkg
        return 1
    fi

    logMe "Cleaning up utiluti.pkg"
    /bin/rm /tmp/utiluti.pkg

    return 0
}

function check_utiluti_install ()
{
    # Check if utiluti is installed
    # Will install if missing
    #
    # RETURN: None

    logMe "Ensuring that utiluti is installed..."
    if [[ ! -x "${UTI_COMMAND}" ]]; then
        logMe "utiluti is missing - Installing from GitHub"
        install_utiluti
        if [[ $? -ne 0 ]]; then
            logMe "ERROR: Failed to install utiluti"
            logMe "Please install manually from: https://github.com/scriptingosx/utiluti"
            exit 1
        fi
    else
        logMe "utiluti is installed at ${UTI_COMMAND}"
    fi
}

function create_infobox_message()
{
	################################
	#
	# Swift Dialog InfoBox message construct
	#
	################################

	# Get macOS version properly
	MACOS_NAME=$( /usr/bin/sw_vers -productName )
	MACOS_VERSION=$( /usr/bin/sw_vers -productVersion )

	# Ensure variables have values (shouldn't be needed if export works)
	[[ -z "$MAC_CPU" ]] && MAC_CPU="Unknown CPU"
	[[ -z "$MAC_RAM" ]] && MAC_RAM="Unknown"

	SD_INFO_BOX_MSG="## System Info ##<br>"
	SD_INFO_BOX_MSG+="${MAC_CPU}<br>"
	SD_INFO_BOX_MSG+="{serialnumber}<br>"
	SD_INFO_BOX_MSG+="${MAC_RAM} RAM<br>"
	SD_INFO_BOX_MSG+="${FREE_DISK_SPACE}GB Available<br>"
	SD_INFO_BOX_MSG+="${MACOS_NAME} ${MACOS_VERSION}<br>"
}

function cleanup_and_exit ()
{
	[[ -f ${JSON_OPTIONS} ]] && /bin/rm -rf ${JSON_OPTIONS}
	[[ -f ${TMP_FILE_STORAGE} ]] && /bin/rm -rf ${TMP_FILE_STORAGE}
    [[ -f ${DIALOG_COMMAND_FILE} ]] && /bin/rm -rf ${DIALOG_COMMAND_FILE}
    [[ -f ${JSON_DIALOG_BLOB} ]] && /bin/rm -rf ${JSON_DIALOG_BLOB}
	exit $1
}

function runAsUser ()
{
    launchctl asuser "$USER_UID" sudo -u "$LOGGED_IN_USER" "$@"
}

function get_uti_results ()
{
    # PURPOSE: format the uti results into an array and remove the files that are not in the /Applications or /System/Applications folder
    # PRAMS: $1 = utiluti extension to look for
    # RETURN: formatted list of applications
    # EXPECTED: None

    declare utiResults
    declare cleanResults
    declare -a resultsArray
    declare -a cleanArray
    utiResults=$(runAsUser $UTI_COMMAND url list ${1})
    if [[ -z "${utiResults}" ]]; then # the default list function returned blank, so we need to locate this another way
        utiResults=$(runAsUser $UTI_COMMAND get-uti ${1})
        utiResults=$(runAsUser $UTI_COMMAND type list ${utiResults})
    fi
    cleanResults=$(echo "${utiResults}" |  grep -E '^(/System|/Applications)' | sed -e 's|^/Applications/||' -e 's|^/System/Applications/||' -e 's|^/System/Volumes/Preboot/Cryptexes/App/System/Applications/||' -e 's|^/System/Library/CoreServices/||' ) #remove the prefixes from the app names
    resultsArray=("${(@f)cleanResults}")
    for item in "${resultsArray[@]}"; do
        cleanArray+=("\"${item}\"",)
    done
    echo ${cleanArray[@]}
}

function get_default_uti_app ()
{
    # PURPOSE: determine the default app for the uti prefix
    # PRAMS: $1 = utiluti command to run
    # RETURN: app assigned to that uti
    # EXPECTED: None
    utiResults=$(runAsUser $UTI_COMMAND url ${1})
    if [[ "${utiResults}" == '<no default app found>' ]]; then # the default list function returned blank, so we need to locate this another way
        utiType=$(runAsUser $UTI_COMMAND get-uti ${1})
        utiResults=$(runAsUser $UTI_COMMAND type ${utiType})
    fi
    echo $utiResults |  grep -E '^(/System|/Applications)' | sed -e 's|^/Applications/||' -e 's|^/System/Applications/||' -e 's|^/System/Volumes/Preboot/Cryptexes/App/System/Applications/||' -e 's|^/System/Library/CoreServices/||'
}

function set_uti_results ()
{
    # PURPOSE: Set the default app for the given extension type
    # PRAMS: $1 - Default Application to set
    #        $2 - File Type extension to change
    # RETURN: None
    # EXPECTED: None
    declare tmp
    declare bundleId
    declare appName="${1//\"/}"
    declare filePath
    declare results

    # Look up the default bundleID that is associated currently
    defaultBundleId=$(runAsUser $UTI_COMMAND get-uti ${2})

    # Locate where the file is on the system
    if [[ -e "/Applications/$appName" ]]; then
        filePath="/Applications/$appName"
    elif [[ -e "/System/Applications/$appName" ]]; then
        filePath="/System/Applications/$appName"
    else
        filePath="/System/Library/CoreServices/$appName"
    fi

    # Look up the bundleID of the app that we are changing it to
    bundleId=$(runAsUser $UTI_COMMAND app id "${filePath}")

    # Evaluate the options and set the UTI command accordingly
    case "${2:l}" in
        http|ftp|ssh|mailto)
            results=$(runAsUser $UTI_COMMAND url set "${2:l}" "$bundleId")
            ;;
        *)
            results=$(runAsUser $UTI_COMMAND type set $defaultBundleId $bundleId)
            ;;
    esac
    logMe "Results: $results"
}

function construct_dialog_header_settings ()
{
    # Construct the basic Swift Dialog screen info that is used on all messages
    #
    # RETURN: None
	# VARIABLES expected: All of the Window variables should be set
	# PARMS Passed: $1 is message to be displayed on the window

	echo '{
        "icon" : "'${SD_ICON}'",
        "message" : "'$1'",
        "infobox" : "'${SD_INFO_BOX_MSG}'",
        "overlayicon" : "'${OVERLAY_ICON}'",
        "ontop" : "true",
        "bannertitle" : "'${SD_WINDOW_TITLE}'",
        "titlefont" : "shadow=1",
        "helpmessage" : "Choose what application(s) you want to open a particular type of file with.<br>Click on the 'More Info' button for assistance on setting UTI types.",
        "infobutton" : "More Info",
        "infobuttonaction" : "https://github.com/scriptingosx/utiluti",
        "width" : 920,
        "height" : 520,
        "button1text" : "OK",
        "button2text" : "Cancel",
        "moveable" : "true",
        "json" : "true",
        "quitkey" : "0",
        "messageposition" : "top",'
}

function create_dropdown_message_body ()
{
    # PURPOSE: Construct the List item body of the dialog box
    # "listitem" : [
    #			{"title" : "macOS Version:", "icon" : "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FinderIcon.icns", "status" : "${macOS_version_icon}", "statustext" : "$sw_vers"},

    # RETURN: None
    # EXPECTED: message
    # PARMS: $1 - title (Display)
    #        $2 - values (comma separated list)
    #        $3 - default item
    #        $4 - first or last - construct appropriate listitem heders / footers
    #        $5 - Trailing closure commands
    #        $6 - Name of dropdown item

    declare line && line=""

    [[ "$4:l" == "first" ]] && line+=' "selectitems" : ['
    [[ ! -z $1 ]] && line+='{"title" : "'$1'", "values" : ['$2']'
    [[ ! -z $3 ]] && line+=', "default" : "'$3'"'
    [[ ! -z $6 ]] && line+=', "name" : "'$6'", "required" : "true", '
    [[ ! -z $5 ]] && line+="$5"
    [[ "$4:l" == "last" ]] && line+='],'
    echo $line >> ${JSON_DIALOG_BLOB}
}

function create_dropdown_list ()
{
    # PURPOSE: Create the dropdown list for the dialog box
    # RETURN: None
    # EXPECTED: JSON_DIALOG_BLOB should be defined
    # PARMS: $1 - message to be displayed on the window
    #        $2 - tyoe of data to parse XML or JSON
    #        #3 - key to parse for list items
    #        $4 - string to parse for list items
    # EXPECTED: None
    declare -a array

    construct_dialog_header_settings $1 > "${JSON_DIALOG_BLOB}"
    create_dropdown_message_body "" "" "first"

    # Parse the XML or JSON data and create list items

    if [[ "$2:l" == "json" ]]; then
        # If the second parameter is XML, then parse the XML data
        xml_blob=$(echo $4 | jq -r '.results[]'$3)
    else
        # If the second parameter is JSON, then parse the JSON data
        xml_blob=$(echo $4 | xmllint --xpath '//'$3 - 2) #>/dev/null)
    fi

    echo $xml_blob | while IFS= read -r line; do
        # Remove the <name> and </name> tags from the line and trailing spaces
        line="${${line#*<name>}%</name>*}"
        line=$(echo $line | sed 's/[[:space:]]*$//')
        array+='"'$line'",'
    done
    # Remove the trailing comma from the array
    array="${array%,}"
    create_dropdown_message_body "Select Groups:" "$array" "last"

    #create_dropdown_message_body "" "" "last"
    update_display_list "Create"
}

function construct_dropdown_list_items ()
{
    # PURPOSE: Construct the list of items for the dropdowb menu
    # RETURN: formatted list of items
    # EXPECTED: None
    # PARMS: $1 - XML variable to parse
    declare xml_blob
    declare line
    xml_blob=$(echo $1 |jq -r '.computer_groups[] | "\(.id) - \(.name)"')
    echo $xml_blob | while IFS= read -r line; do
        # Remove the <name> and </name> tags from the line and trailing spaces
        line="${${line#*<name>}%</name>*}"
        line=$(echo $line | sed 's/[[:space:]]*$//')
        array+='"'$line'",'
    done
    # Remove the trailing comma from the array
    array="${array%,}"
    echo $array
}

####################################################################################################
#
# Main Script
#
####################################################################################################

declare -a utiHttp
declare -a utiMailTo
declare -a utiFtp
declare -a utiXLS
declare -a utiDoc
declare -a utiTxt
declare -a utiPDF

autoload 'is-at-least'

check_directory_structure
check_swift_dialog_install
check_utiluti_install
create_infobox_message

# read in the applications for each file type
# Customize your own extension list here
# call the "set_uti" function for each file type extension
# if this list gets extensive, you will need to adjust the window height in the "construct_display_header_settings" function

logMe "Constructing application list(s)"
utiMailTo=$(get_uti_results "mailto")
utiHttp=$(get_uti_results "https")
utiFtp=$(get_uti_results "ftp")
utiXLS=$(get_uti_results "xlsx")
utiDoc=$(get_uti_results "docx")
utiTxt=$(get_uti_results "txt")
utiPDF=$(get_uti_results "pdf")
utiMD=$(get_uti_results "md")

# if you need to add new app types in here, make sure to use this template:
# create_dropdown_message_body "Documents (doc):" "$utiDoc" "$(get_default_uti_app "docx")"
# echo "}," >> $JSON_DIALOG_BLOB
#
# You need to copy/edit/paste both lines above into the code
logMe "Constructing display options"
message="$SD_DIALOG_GREETING, $SD_FIRST_NAME. The default applications for each file types are shown below.  You can optionally change which applications will be used when you open the following types of files:"
construct_dialog_header_settings "$message" > "${JSON_DIALOG_BLOB}"
create_dropdown_message_body "" "" "" "first"
create_dropdown_message_body "Email App (mailto):" "$utiMailTo" "$(get_default_uti_app "mailto")"
echo "}," >> $JSON_DIALOG_BLOB
create_dropdown_message_body "Web Browser (http):" "$utiHttp" "$(get_default_uti_app "http")"
echo "}," >> $JSON_DIALOG_BLOB
create_dropdown_message_body "File Transfer (ftp):" "$utiFtp" "$(get_default_uti_app "ftp")"
echo "}," >> $JSON_DIALOG_BLOB
create_dropdown_message_body "Spreadsheet (xlsx):" "$utiXLS" "$(get_default_uti_app "xlsx")"
echo "}," >> $JSON_DIALOG_BLOB
create_dropdown_message_body "Documents (doc):" "$utiDoc" "$(get_default_uti_app "docx")"
echo "}," >> $JSON_DIALOG_BLOB
create_dropdown_message_body "Text Files (txt):" "$utiTxt" "$(get_default_uti_app "txt")"
echo "}," >> $JSON_DIALOG_BLOB
create_dropdown_message_body "Markdown (md):" "$utiTxt" "$(get_default_uti_app "md")"
echo "}," >> $JSON_DIALOG_BLOB
create_dropdown_message_body "Portable Doc Format (pdf):" "$utiPDF" "$(get_default_uti_app "pdf")"
echo "}]}" >> $JSON_DIALOG_BLOB

# Show the dialog screen and get the results
results=$(${SW_DIALOG} --json --jsonfile "${JSON_DIALOG_BLOB}") 2>/dev/null
returnCode=$?

[[ $returnCode == 2 ]] && {logMe "Cancel button pressed"; cleanup_and_exit 0;}

# Extract the results
# Make sure to extract your results from your own extension
resultsMailTo=$(echo $results | jq '.["Email App (mailto):"].selectedValue')
resultsHttp=$(echo $results | jq '.["Web Browser (http):"].selectedValue')
resultsFtp=$(echo $results | jq '.["File Transfer (ftp):"].selectedValue')
resultsXls=$(echo $results | jq '.["Spreadsheet (xlsx):"].selectedValue')
resultsDoc=$(echo $results | jq '.["Documents (doc):"].selectedValue')
resultsTxt=$(echo $results | jq '.["Text Files (txt):" ].selectedValue')
resultsPDF=$(echo $results | jq '.["Portable Doc Format (pdf):" ].selectedValue')
resultsMD=$(echo $results | jq '.["Markdown (md):"  ].selectedValue')


# and then set the new defaults
# Call the "set_uti" function to set the results
set_uti_results $resultsMailTo "mailto"
set_uti_results $resultsHttp "http"
set_uti_results $resultsFtp "ftp"
set_uti_results $resultsXls "xlsx"
set_uti_results $resultsDoc "docx"
set_uti_results $resultsTxt "txt"
set_uti_results $resultsPDF "pdf"
set_uti_results $resultsMD "md"

cleanup_and_exit 0
