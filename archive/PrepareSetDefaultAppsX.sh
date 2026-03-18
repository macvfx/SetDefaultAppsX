#!/bin/zsh
#
# PrepareSetDefaultAppsX.sh
#
# Version: 1.0
# Created: 2025-12-15
#
# Script Purpose: Prepare the system for SetDefaultAppsX.sh by creating necessary directories
#                 This script should be run ONCE by an administrator before deploying SetDefaultAppsX.sh
#
# Usage: sudo ./PrepareSetDefaultAppsX.sh
#

######################################################################################################
#
# Check if running as root
#
######################################################################################################

if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root (use sudo)"
   echo "Usage: sudo $0"
   exit 1
fi

######################################################################################################
#
# Variables
#
######################################################################################################

SUPPORT_DIR="/Library/Application Support/SetDefaultAppsX"
LOG_DIR="${SUPPORT_DIR}/logs"
SUPPORT_FILES_DIR="${SUPPORT_DIR}/SupportFiles"

######################################################################################################
#
# Create Directory Structure
#
######################################################################################################

echo "========================================="
echo "SetDefaultAppsX Preparation Script"
echo "========================================="
echo ""

# Create main support directory
if [[ ! -d "${SUPPORT_DIR}" ]]; then
    echo "Creating directory: ${SUPPORT_DIR}"
    /bin/mkdir -p "${SUPPORT_DIR}"
    /bin/chmod 755 "${SUPPORT_DIR}"
else
    echo "Directory already exists: ${SUPPORT_DIR}"
fi

# Create logs directory
if [[ ! -d "${LOG_DIR}" ]]; then
    echo "Creating directory: ${LOG_DIR}"
    /bin/mkdir -p "${LOG_DIR}"
    /bin/chmod 755 "${LOG_DIR}"
else
    echo "Directory already exists: ${LOG_DIR}"
fi

# Create support files directory (for banner images, etc.)
if [[ ! -d "${SUPPORT_FILES_DIR}" ]]; then
    echo "Creating directory: ${SUPPORT_FILES_DIR}"
    /bin/mkdir -p "${SUPPORT_FILES_DIR}"
    /bin/chmod 755 "${SUPPORT_FILES_DIR}"
else
    echo "Directory already exists: ${SUPPORT_FILES_DIR}"
fi

# Set ownership to allow all users to write logs
echo "Setting permissions to allow all users to write logs..."
/bin/chmod 777 "${LOG_DIR}"

echo ""
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo ""
echo "The following directories have been created:"
echo "  - ${SUPPORT_DIR}"
echo "  - ${LOG_DIR}"
echo "  - ${SUPPORT_FILES_DIR}"
echo ""
echo "Next Steps:"
echo "  1. (Optional) Place your banner image at:"
echo "     ${SUPPORT_FILES_DIR}/SD_BannerImage.png"
echo ""
echo "  2. Run SetDefaultAppsX.sh as a normal user (no sudo required)"
echo ""
echo "========================================="

exit 0
