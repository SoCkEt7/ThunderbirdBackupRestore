#!/bin/bash

#########################################################
# Interactive Thunderbird Backup and Restore Tool v3.0
# A comprehensive tool to backup and restore Thunderbird
# email settings, messages, and configurations
#########################################################

# Color definitions
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Print fancy header
print_header() {
    clear
    echo -e "${BLUE}╔═════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  ${BOLD}  THUNDERBIRD BACKUP AND RESTORE TOOL v3.0     ${NC}${BLUE}║${NC}"
    echo -e "${BLUE}╚═════════════════════════════════════════════════╝${NC}"
    echo
}

# Show progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))

    printf "\r[${CYAN}"
    for ((i=0; i<completed; i++)); do
        printf "#"
    done
    printf "${NC}"
    for ((i=0; i<remaining; i++)); do
        printf "-"
    done
    printf "${NC}] %3d%% (%d/%d)" $percentage $current $total
}

# Format file size
format_size() {
    local size=$1

    if [ $size -ge 1073741824 ]; then
        echo $(echo "scale=2; $size / 1073741824" | bc)" GB"
    elif [ $size -ge 1048576 ]; then
        echo $(echo "scale=2; $size / 1048576" | bc)" MB"
    elif [ $size -ge 1024 ]; then
        echo $(echo "scale=2; $size / 1024" | bc)" KB"
    else
        echo "$size bytes"
    fi
}

# Detect operating system
detect_os() {
    OS="unknown"
    OS_NAME="Unknown OS"

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        if [ -f /etc/os-release ]; then
            OS_NAME=$(grep -oP '(?<=^NAME=).+' /etc/os-release | tr -d '"')
        else
            OS_NAME="Linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="mac"
        if command -v sw_vers &> /dev/null; then
            OS_NAME="macOS $(sw_vers -productVersion)"
        else
            OS_NAME="macOS"
        fi
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
        OS="windows"
        OS_NAME="Windows"
    else
        OS="unknown"
        OS_NAME="Unknown OS"
    fi

    echo -e "${GREEN}Detected system: ${BOLD}${OS_NAME}${NC} (${OS})"
}

# Check if Thunderbird is running
check_thunderbird_running() {
    case $OS in
        linux)
            if pgrep -x "thunderbird" > /dev/null; then
                return 0
            else
                return 1
            fi
            ;;
        mac)
            if pgrep -x "thunderbird" > /dev/null || pgrep -x "Thunderbird" > /dev/null; then
                return 0
            else
                return 1
            fi
            ;;
        windows)
            if tasklist 2>/dev/null | grep -i "thunderbird.exe" > /dev/null; then
                return 0
            else
                return 1
            fi
            ;;
        *)
            # If we can't detect, assume it's not running
            return 1
            ;;
    esac
}

# Stop Thunderbird if it's running
stop_thunderbird() {
    if check_thunderbird_running; then
        echo -e "${YELLOW}Thunderbird is currently running.${NC}"
        echo -e "${YELLOW}For a complete operation, it's recommended to close Thunderbird first.${NC}"
        echo -e "${YELLOW}Some files might be locked and not properly processed.${NC}"
        read -p "Stop Thunderbird automatically? (y/n/q): " stop_choice

        if [[ "$stop_choice" == "q" || "$stop_choice" == "Q" ]]; then
            echo -e "${RED}Operation aborted.${NC}"
            exit 0
        elif [[ "$stop_choice" == "y" || "$stop_choice" == "Y" ]]; then
            echo -e "${BLUE}Attempting to close Thunderbird...${NC}"

            case $OS in
                linux)
                    killall thunderbird 2>/dev/null || pkill thunderbird
                    ;;
                mac)
                    killall Thunderbird 2>/dev/null || pkill Thunderbird
                    ;;
                windows)
                    taskkill /F /IM thunderbird.exe 2>/dev/null
                    ;;
            esac

            # Wait for process to terminate
            echo -e "${BLUE}Waiting for Thunderbird to close...${NC}"
            for i in {1..10}; do
                if ! check_thunderbird_running; then
                    echo -e "${GREEN}Thunderbird has been closed.${NC}"
                    break
                fi
                sleep 1
                show_progress $i 10
            done
            echo ""

            if check_thunderbird_running; then
                echo -e "${RED}Failed to close Thunderbird. Please close it manually.${NC}"
                read -p "Press Enter to continue once Thunderbird is closed or q to quit: " choice
                if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
                    echo -e "${RED}Operation aborted.${NC}"
                    exit 0
                fi
            fi
        else
            echo -e "${YELLOW}Continuing with Thunderbird running. Some files may not be properly processed.${NC}"
        fi
    fi
}

# Find Thunderbird profile directory
find_profile_dir() {
    PROFILE_DIR=""
    ALTERNATIVE_DIRS=()

    case $OS in
        linux)
            PROFILE_DIR="$HOME/.thunderbird"
            ALTERNATIVE_DIRS=("$HOME/.var/app/org.mozilla.Thunderbird/data/thunderbird" "$HOME/snap/thunderbird/common/.thunderbird")
            ;;
        mac)
            PROFILE_DIR="$HOME/Library/Thunderbird"
            ALTERNATIVE_DIRS=("$HOME/Library/Application Support/Thunderbird")
            ;;
        windows)
            PROFILE_DIR="$APPDATA/Thunderbird"
            ALTERNATIVE_DIRS=("$APPDATA/Mozilla/Thunderbird" "$LOCALAPPDATA/Thunderbird")
            ;;
        *)
            echo -e "${RED}Error: Unsupported operating system.${NC}"
            exit 1
            ;;
    esac

    # Check if main profile directory exists, otherwise try alternatives
    if [ ! -d "$PROFILE_DIR" ]; then
        echo -e "${YELLOW}Primary profile directory not found at: ${PROFILE_DIR}${NC}"
        echo -e "${BLUE}Checking alternative locations...${NC}"

        for alt_dir in "${ALTERNATIVE_DIRS[@]}"; do
            if [ -d "$alt_dir" ]; then
                echo -e "${GREEN}Found Thunderbird profile directory at: ${alt_dir}${NC}"
                PROFILE_DIR="$alt_dir"
                break
            fi
        done
    fi

    # If still not found, ask user
    if [ ! -d "$PROFILE_DIR" ]; then
        echo -e "${YELLOW}Could not locate Thunderbird profile directory automatically.${NC}"
        echo -e "${YELLOW}Please enter the full path to your Thunderbird profile directory:${NC}"
        read -p "> " custom_profile_dir

        if [ -d "$custom_profile_dir" ]; then
            PROFILE_DIR="$custom_profile_dir"
        else
            echo -e "${RED}The specified directory does not exist.${NC}"
            exit 1
        fi
    fi

    echo -e "${GREEN}Using Thunderbird profile directory: ${BOLD}${PROFILE_DIR}${NC}"
}

# Backup a profile
backup_profile() {
    local profile_path=$1
    local profile_name=$2
    local backup_path="${BACKUP_DIR}/profiles/${profile_name}"

    echo -e "\n${BLUE}Backing up profile: ${YELLOW}${BOLD}${profile_name}${NC}"

    # Create profile backup directory
    mkdir -p "$backup_path"

    # Important folders/files to backup
    key_items=(
        # Essential configuration
        "prefs.js"           # Main preferences file
        "user.js"            # User preference overrides
        "persdict.dat"       # Personal dictionary
        "hostperm.1"         # Site-specific permissions
        "permissions.sqlite" # Permissions database
        "handlers.json"      # Protocol handlers
        "mimeTypes.rdf"      # MIME types configuration
        "compatability.ini"  # Compatibility information

        # Security and authentication
        "cert9.db"           # Security certificate database (newer versions)
        "cert8.db"           # Security certificate database (older versions)
        "key4.db"            # Password database (newer versions)
        "key3.db"            # Password database (older versions)
        "logins.json"        # Saved logins
        "signons.sqlite"     # Password storage
        "pkcs11.txt"         # Security module config

        # Email storage and caching
        "Mail"               # Mail folders and messages
        "ImapMail"           # IMAP mail folders
        "global-messages-db.sqlite" # Global message database

        # Filtering and organization
        "junk.trainDB"       # Junk/spam filter training data
        "filters.dat"        # Mail filters
        "msgFilterRules.dat" # Message filter rules
        "training.dat"       # Bayesian filter training data
        "virtualFolders.dat" # Saved searches

        # Contact management
        "abook.mab"          # Address book (older versions)
        "abook-1.mab"        # Address book (newer versions)
        "history.mab"        # Mail history
        "addressBook"        # Address book directory
        "impab.mab"          # Import address book
        "personaladdressbook.mab" # Personal address book

        # Customization and addons
        "extensions"         # Add-ons and extensions
        "extensions.json"    # Extensions data
        "extensions.ini"     # Extensions configuration
        "extensions.sqlite"  # Extensions database
        "extension-preferences.json" # Extension preferences

        # Layout and appearance
        "chrome"             # UI customizations

        # Calendar and events
        "calendar-data"      # Calendar data
        "calendar.sqlite"    # Calendar database

        # Templates and signatures
        "signatures"         # Signatures directory
        "signatureSwitch"    # Signature configurations
        "stationery"         # Email templates
        "Templates"          # Template directory

        # Draft and offline content
        "drafts"             # Email drafts
        "SiteSecurityServiceState.txt" # Security states

        # Local folders and cached content
        "panacea.dat"        # Local folders info
        "localstore.rdf"     # Window positions and sizes

        # Search and indexing
        "search.sqlite"      # Search index database
        "search.json"        # Search configuration

        # RSS feeds
        "feeds"              # RSS feed data
    )

    # Count items for progress indication
    local total_items=${#key_items[@]}
    local current_item=0
    local successful_copies=0
    local failed_copies=0

    # Copy each key item if it exists
    for item in "${key_items[@]}"; do
        current_item=$((current_item + 1))

        # Check if file exists
        if [ -e "${profile_path}/${item}" ]; then
            # Show what we're copying
            printf "\r${CYAN}Copying: %-30s${NC}" "$item"

            # Copy with error handling
            if cp -r "${profile_path}/${item}" "${backup_path}/" 2>/dev/null; then
                successful_copies=$((successful_copies + 1))
            else
                failed_copies=$((failed_copies + 1))
                echo -e "\r${YELLOW}Warning: Failed to copy ${item}${NC}"
            fi
        fi

        # Show progress
        show_progress $current_item $total_items
    done
    echo "" # New line after progress bar

    # Find and copy all signature files that might be in other locations
    echo -e "${BLUE}Searching for additional signature files...${NC}"
    signature_files=$(find "${profile_path}" -name "*.sig" -o -name "*signature*.html" -o -name "*signature*.txt" 2>/dev/null)

    if [ -n "$signature_files" ]; then
        mkdir -p "${backup_path}/additional_signatures"
        while read -r sig_file; do
            if [ -f "$sig_file" ]; then
                cp "$sig_file" "${backup_path}/additional_signatures/" 2>/dev/null
            fi
        done <<< "$signature_files"
        echo -e "${GREEN}✓ Additional signature files backed up${NC}"
    fi

    echo -e "${GREEN}✓ Profile ${profile_name} backed up successfully${NC}"
    echo -e "   ${GREEN}Files successfully copied: ${successful_copies}${NC}"
    if [ $failed_copies -gt 0 ]; then
        echo -e "   ${YELLOW}Files failed to copy: ${failed_copies}${NC}"
    fi
}

# Run backup process
run_backup() {
    print_header
    echo -e "${BOLD}BACKUP MODE${NC}"
    echo -e "${BLUE}This will backup your Thunderbird settings, profiles, and emails.${NC}"
    echo

    # Detect OS
    detect_os

    # Stop Thunderbird if running
    stop_thunderbird

    # Find profile directory
    find_profile_dir

    # Get current date and time for backup name
    CURRENT_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
    BACKUP_NAME="thunderbird_backup_${CURRENT_DATE}"

    # Set default backup location based on OS
    DEFAULT_BACKUP_PATH="$(pwd)"
    case $OS in
        linux)
            if [ -d "$HOME/Documents" ]; then
                DEFAULT_BACKUP_PATH="$HOME/Documents"
            fi
            ;;
        mac)
            if [ -d "$HOME/Documents" ]; then
                DEFAULT_BACKUP_PATH="$HOME/Documents"
            fi
            ;;
        windows)
            if [ -d "$USERPROFILE/Documents" ]; then
                DEFAULT_BACKUP_PATH="$USERPROFILE/Documents"
            fi
            ;;
    esac

    # Ask for backup location with better prompt
    echo -e "${YELLOW}Where would you like to save the backup?${NC}"
    echo -e "Enter path or press Enter for default [${DEFAULT_BACKUP_PATH}]:"
    read BACKUP_PATH

    # If no input, use default path
    if [ -z "$BACKUP_PATH" ]; then
        BACKUP_PATH="$DEFAULT_BACKUP_PATH"
    fi

    # Expand tilde if present
    BACKUP_PATH="${BACKUP_PATH/#\~/$HOME}"

    # Check if BACKUP_PATH exists and is writable
    if [ ! -d "$BACKUP_PATH" ]; then
        echo -e "${YELLOW}Directory $BACKUP_PATH does not exist. Would you like to create it? (y/n)${NC}"
        read create_dir
        if [[ "$create_dir" == "y" || "$create_dir" == "Y" ]]; then
            mkdir -p "$BACKUP_PATH"
            if [ $? -ne 0 ]; then
                echo -e "${RED}Error: Could not create directory $BACKUP_PATH${NC}"
                exit 1
            fi
        else
            echo -e "${RED}Backup aborted.${NC}"
            exit 1
        fi
    fi

    # Test if directory is writable
    if [ ! -w "$BACKUP_PATH" ]; then
        echo -e "${RED}Error: Cannot write to $BACKUP_PATH${NC}"
        exit 1
    fi

    # Create backup directory with unique name
    BACKUP_DIR="${BACKUP_PATH}/${BACKUP_NAME}"

    # Check if directory already exists (shouldn't happen with timestamp)
    if [ -d "$BACKUP_DIR" ]; then
        echo -e "${YELLOW}Warning: Backup directory already exists.${NC}"
        echo -e "${YELLOW}Using a unique name to prevent overwriting.${NC}"
        BACKUP_NAME="${BACKUP_NAME}_$(date +%s)"
        BACKUP_DIR="${BACKUP_PATH}/${BACKUP_NAME}"
    fi

    mkdir -p "$BACKUP_DIR"

    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${RED}Error: Could not create backup directory at $BACKUP_DIR${NC}"
        exit 1
    fi

    echo -e "${GREEN}Backup will be created at: ${BOLD}${BACKUP_DIR}${NC}"

    # Find and backup all profiles
    echo -e "${BLUE}Looking for Thunderbird profiles...${NC}"

    # Create profiles backup directory
    mkdir -p "${BACKUP_DIR}/profiles"

    # Parse profiles.ini
    PROFILES_INI="${PROFILE_DIR}/profiles.ini"
    if [ -f "$PROFILES_INI" ]; then
        echo -e "${GREEN}Found profiles.ini${NC}"

        # Copy profiles.ini
        cp "$PROFILES_INI" "${BACKUP_DIR}/"

        # Extract profile paths and names
        profile_sections=$(grep "^\[Profile" "$PROFILES_INI")
        profile_count=0

        # Process each profile
        while IFS= read -r line; do
            profile_num=$(echo "$line" | sed 's/\[Profile\(.*\)\]/\1/')

            # Get profile path
            is_relative=$(grep -A 10 "^\[Profile${profile_num}\]" "$PROFILES_INI" | grep "^IsRelative=" | cut -d"=" -f2 | tr -d '\r')
            path_value=$(grep -A 10 "^\[Profile${profile_num}\]" "$PROFILES_INI" | grep "^Path=" | cut -d"=" -f2 | tr -d '\r')

            # Get profile name if available
            profile_name=$(grep -A 10 "^\[Profile${profile_num}\]" "$PROFILES_INI" | grep "^Name=" | cut -d"=" -f2 | tr -d '\r')
            if [ -z "$profile_name" ]; then
                profile_name="Profile${profile_num}"
            fi

            # Determine actual profile path
            profile_path=""
            if [ "$is_relative" = "1" ]; then
                profile_path="${PROFILE_DIR}/${path_value}"
            else
                profile_path="$path_value"
            fi

            # Check if profile exists
            if [ -d "$profile_path" ]; then
                echo -e "${GREEN}Found profile: ${profile_name} at ${profile_path}${NC}"
                backup_profile "$profile_path" "$profile_name"
                profile_count=$((profile_count + 1))
            else
                echo -e "${YELLOW}Warning: Profile directory not found: ${profile_path}${NC}"
            fi
        done <<< "$profile_sections"

        if [ $profile_count -eq 0 ]; then
            echo -e "${YELLOW}Warning: No profiles found in profiles.ini${NC}"
        else
            echo -e "${GREEN}Backed up ${profile_count} profile(s)${NC}"
        fi
    else
        echo -e "${YELLOW}Warning: profiles.ini not found at ${PROFILES_INI}${NC}"
        echo -e "${YELLOW}Looking for default profile directory...${NC}"

        # Try to find default profile directory
        default_profile=$(find "$PROFILE_DIR" -name "*.default" -type d | head -n 1)
        if [ -n "$default_profile" ]; then
            echo -e "${GREEN}Found default profile at ${default_profile}${NC}"
            backup_profile "$default_profile" "default"
        else
            echo -e "${RED}Error: Could not find any Thunderbird profiles${NC}"
            exit 1
        fi
    fi

    # Backup global settings if available
    GLOBAL_SETTINGS=(
        "global-messages-db.sqlite" # Global message database
        "compatibility.ini"         # Compatibility information
        "extension-data"            # Extension data
        "crashes"                   # Crash reports
        "mail-addons"               # Mail add-ons
        "calendar-addons"           # Calendar add-ons
    )

    echo -e "${BLUE}Backing up global settings...${NC}"
    mkdir -p "${BACKUP_DIR}/global"

    for item in "${GLOBAL_SETTINGS[@]}"; do
        if [ -e "${PROFILE_DIR}/${item}" ]; then
            echo -e "  ${GREEN}Copying global setting: ${item}${NC}"
            cp -r "${PROFILE_DIR}/${item}" "${BACKUP_DIR}/global/"
        fi
    done

    # Create a metadata file with backup information
    echo -e "${BLUE}Creating backup metadata...${NC}"
    cat > "${BACKUP_DIR}/backup-info.txt" << EOF
Thunderbird Backup Information
==============================
Date: $(date)
Hostname: $(hostname)
OS: $OS
Thunderbird Profile Directory: $PROFILE_DIR

This backup contains:
- Profile folders (containing accounts, messages, filters, etc.)
- Password databases and saved logins
- Address books
- Mail folders and messages
- Extensions and add-ons
- Signatures
- Preferences and configuration

To restore:
1. Close Thunderbird if it's running
2. Use the restore option of this tool
3. Or manually replace the contents of your Thunderbird profile directory with the backup files
4. Restart Thunderbird
EOF

    # Create a copy of this script in the backup
    echo -e "${BLUE}Adding restoration script to backup...${NC}"
    cp "$0" "${BACKUP_DIR}/thunderbird_backup_restore.sh"
    chmod +x "${BACKUP_DIR}/thunderbird_backup_restore.sh"

    # Create archive of backup
    echo -e "${BLUE}Creating backup archive...${NC}"
    cd "$BACKUP_PATH"
    tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"

    # Verify backup archive
    if [ -f "${BACKUP_PATH}/${BACKUP_NAME}.tar.gz" ]; then
        echo -e "${GREEN}✓ Backup archive created successfully: ${BACKUP_PATH}/${BACKUP_NAME}.tar.gz${NC}"
        echo -e "${GREEN}  Original backup files are also available at: ${BACKUP_DIR}${NC}"

        # Save the name of the last backup
        echo "$BACKUP_NAME" > "${BACKUP_PATH}/last_thunderbird_backup.txt"
    else
        echo -e "${RED}Failed to create backup archive${NC}"
        echo -e "${YELLOW}Your backup files are still available at: ${BACKUP_DIR}${NC}"
    fi

    echo -e "${BLUE}╔═════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ ${GREEN}    Thunderbird backup completed successfully!    ${NC}${BLUE}║${NC}"
    echo -e "${BLUE}╚═════════════════════════════════════════════════╝${NC}"

    echo -e "${YELLOW}Notes:${NC}"
    echo -e "1. The backup includes all profiles, settings, and messages"
    echo -e "2. To restore, use the restore option of this tool"
    echo -e "3. Keep this backup in a safe place"
    echo -e "4. For full protection, store this backup on an external device or cloud storage"
}

# Run restore process
run_restore() {
    print_header
    echo -e "${BOLD}RESTORE MODE${NC}"
    echo -e "${BLUE}This will restore your Thunderbird settings, profiles, and emails from a backup.${NC}"
    echo -e "${RED}WARNING: This will replace your current Thunderbird configuration.${NC}"
    echo

    # Detect OS
    detect_os

    # Stop Thunderbird if running
    stop_thunderbird

    # Find profile directory
    find_profile_dir

    # Get backup location
    echo -e "${YELLOW}Where is your backup located?${NC}"
    echo -e "Enter the directory where your backup is stored:"
    read RESTORE_PATH

    # Expand tilde if present
    RESTORE_PATH="${RESTORE_PATH/#\~/$HOME}"

    # Check if path exists
    if [ ! -d "$RESTORE_PATH" ]; then
        echo -e "${RED}Error: The specified backup directory does not exist.${NC}"
        exit 1
    fi

    # Look for backups
    BACKUP_ARCHIVES=()
    BACKUP_FOLDERS=()

    # Check for archive files
    for archive in "$RESTORE_PATH"/*thunderbird_backup*.tar.gz; do
        if [ -f "$archive" ]; then
            BACKUP_ARCHIVES+=("$archive")
        fi
    done

    # Check for backup folders
    for folder in "$RESTORE_PATH"/*thunderbird_backup*/; do
        if [ -d "$folder" ]; then
            BACKUP_FOLDERS+=("$folder")
        fi
    done

    # No backups found
    if [ ${#BACKUP_ARCHIVES[@]} -eq 0 ] && [ ${#BACKUP_FOLDERS[@]} -eq 0 ]; then
        echo -e "${RED}Error: No Thunderbird backups found in ${RESTORE_PATH}.${NC}"
        echo -e "${YELLOW}Please check the path and try again.${NC}"
        exit 1
    fi

    # Choose backup to restore
    echo -e "${BLUE}Available backups:${NC}"

    AVAILABLE_BACKUPS=()

    # Add archive backups to the list
    for ((i=0; i<${#BACKUP_ARCHIVES[@]}; i++)); do
        archive_name=$(basename "${BACKUP_ARCHIVES[$i]}")
        archive_date=$(echo "$archive_name" | grep -o "[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}_[0-9]\{2\}-[0-9]\{2\}-[0-9]\{2\}")
        AVAILABLE_BACKUPS+=("${BACKUP_ARCHIVES[$i]}")
        echo -e "  $((i+1)). ${YELLOW}[Archive]${NC} ${archive_date}"
    done

    # Add folder backups to the list
    for ((i=0; i<${#BACKUP_FOLDERS[@]}; i++)); do
        folder_name=$(basename "${BACKUP_FOLDERS[$i]}")
        folder_date=$(echo "$folder_name" | grep -o "[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}_[0-9]\{2\}-[0-9]\{2\}-[0-9]\{2\}")
        AVAILABLE_BACKUPS+=("${BACKUP_FOLDERS[$i]}")
        echo -e "  $((i+1+${#BACKUP_ARCHIVES[@]})). ${GREEN}[Folder]${NC} ${folder_date}"
    done

    # Prompt for selection
    echo -e "${YELLOW}Enter the number of the backup you want to restore:${NC}"
    read -p "> " backup_choice

    # Validate input
    if ! [[ "$backup_choice" =~ ^[0-9]+$ ]] || [ "$backup_choice" -lt 1 ] || [ "$backup_choice" -gt ${#AVAILABLE_BACKUPS[@]} ]; then
        echo -e "${RED}Invalid selection. Exiting.${NC}"
        exit 1
    fi

    # Convert to zero-based index
    backup_choice=$((backup_choice-1))

    # Get selected backup
    SELECTED_BACKUP="${AVAILABLE_BACKUPS[$backup_choice]}"
    BACKUP_DIR=""

    # Check if it's an archive or folder
    if [[ "$SELECTED_BACKUP" == *.tar.gz ]]; then
        echo -e "${BLUE}Selected backup archive: ${SELECTED_BACKUP}${NC}"

        # Extract archive
        echo -e "${BLUE}Extracting backup archive...${NC}"
        TEMP_DIR="$RESTORE_PATH/temp_extract_$(date +%s)"
        mkdir -p "$TEMP_DIR"

        tar -xzf "$SELECTED_BACKUP" -C "$TEMP_DIR"

        # Find the extracted folder
        EXTRACTED_FOLDER=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "thunderbird_backup*" | head -n 1)

        if [ -z "$EXTRACTED_FOLDER" ]; then
            echo -e "${RED}Error: Could not find extracted backup folder.${NC}"
            exit 1
        fi

        BACKUP_DIR="$EXTRACTED_FOLDER"
    else
        echo -e "${BLUE}Selected backup folder: ${SELECTED_BACKUP}${NC}"
        BACKUP_DIR="$SELECTED_BACKUP"
    fi

    # Verify backup directory structure
    if [ ! -d "${BACKUP_DIR}/profiles" ]; then
        echo -e "${RED}Error: Invalid backup structure. Missing profiles directory.${NC}"
        exit 1
    fi

    # Final confirmation
    echo -e "${RED}WARNING: This will replace your current Thunderbird configuration.${NC}"
    echo -e "${RED}All existing profiles, settings, and local emails will be overwritten.${NC}"
    read -p "Are you sure you want to continue? (yes/no): " confirm

    if [[ "$confirm" != "yes" ]]; then
        echo -e "${YELLOW}Restore cancelled.${NC}"
        exit 0
    fi

    # Backup current settings
    CURRENT_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
    EXISTING_BACKUP="${PROFILE_DIR}_before_restore_${CURRENT_DATE}"

    echo -e "${BLUE}Creating backup of your current Thunderbird settings...${NC}"
    cp -r "$PROFILE_DIR" "$EXISTING_BACKUP"

    echo -e "${GREEN}Current settings backed up to: ${EXISTING_BACKUP}${NC}"

    # Restore profiles.ini
    if [ -f "${BACKUP_DIR}/profiles.ini" ]; then
        echo -e "${BLUE}Restoring profiles.ini...${NC}"
        cp -f "${BACKUP_DIR}/profiles.ini" "${PROFILE_DIR}/"
    else
        echo -e "${YELLOW}Warning: profiles.ini not found in backup. Continuing anyway...${NC}"
    fi

    # Restore profiles
    echo -e "${BLUE}Restoring profiles...${NC}"

    profile_count=0
    for profile_dir in "${BACKUP_DIR}/profiles"/*; do
        if [ -d "$profile_dir" ]; then
            profile_name=$(basename "$profile_dir")
            echo -e "${GREEN}Restoring profile: ${profile_name}${NC}"

            # Create profile directory if it doesn't exist
            mkdir -p "${PROFILE_DIR}/${profile_name}"

            # Copy profile data with progress tracking
            total_files=$(find "$profile_dir" -type f | wc -l)
            current_file=0

            # Use a single find command with exec to copy files
            find "$profile_dir" -type f | while read file; do
                current_file=$((current_file + 1))

                # Compute relative path
                rel_path="${file#$profile_dir/}"
                target_dir=$(dirname "${PROFILE_DIR}/${profile_name}/${rel_path}")

                # Create target directory if needed
                mkdir -p "$target_dir"

                # Copy file
                cp -f "$file" "${PROFILE_DIR}/${profile_name}/${rel_path}" 2>/dev/null

                # Show progress (update every 10 files)
                if [ $((current_file % 10)) -eq 0 ] || [ $current_file -eq $total_files ]; then
                    show_progress $current_file $total_files
                fi
            done
            echo "" # New line after progress

            profile_count=$((profile_count + 1))
        fi
    done

    # Restore global settings
    if [ -d "${BACKUP_DIR}/global" ]; then
        echo -e "${BLUE}Restoring global settings...${NC}"

        # Copy global settings
        cp -rf "${BACKUP_DIR}/global/"* "${PROFILE_DIR}/" 2>/dev/null
    fi

    # Cleanup temp directory if we extracted from an archive
    if [[ "$SELECTED_BACKUP" == *.tar.gz ]] && [ -d "$TEMP_DIR" ]; then
        echo -e "${BLUE}Cleaning up temporary files...${NC}"
        rm -rf "$TEMP_DIR"
    fi

    echo -e "${BLUE}╔═════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ ${GREEN}   Thunderbird restore completed successfully!   ${NC}${BLUE}║${NC}"
    echo -e "${BLUE}╚═════════════════════════════════════════════════╝${NC}"

    echo -e "${YELLOW}Notes:${NC}"
    echo -e "1. Your previous Thunderbird settings were backed up to: ${EXISTING_BACKUP}"
    echo -e "2. You can now start Thunderbird"
    echo -e "3. If you encounter any issues, you can restore your original settings from the backup"
}

# Main menu for interactive mode
show_main_menu() {
    while true; do
        print_header
        echo -e "${BOLD}MAIN MENU${NC}"
        echo
        echo -e "  ${CYAN}1${NC}. Create a Thunderbird backup"
        echo -e "  ${CYAN}2${NC}. Restore a Thunderbird backup"
        echo -e "  ${CYAN}3${NC}. Exit"
        echo
        read -p "Enter your choice (1-3): " menu_choice

        case $menu_choice in
            1)
                run_backup
                read -p "Press Enter to return to the main menu..."
                ;;
            2)
                run_restore
                read -p "Press Enter to return to the main menu..."
                ;;
            3)
                echo -e "${GREEN}Exiting. Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Parse command line arguments
if [ $# -eq 0 ]; then
    # No arguments, run in interactive mode
    show_main_menu
else
    # Handle command line arguments
    case "$1" in
        backup)
            run_backup
            ;;
        restore)
            run_restore
            ;;
        --help|-h)
            print_header
            echo -e "Usage: $0 [command]"
            echo
            echo -e "Commands:"
            echo -e "  backup   Create a Thunderbird backup"
            echo -e "  restore  Restore a Thunderbird backup"
            echo -e "  --help   Show this help message"
            echo
            echo -e "If no command is provided, the tool runs in interactive mode."
            ;;
        *)
            echo -e "${RED}Unknown command: $1${NC}"
            echo -e "Use '$0 --help' for usage information."
            exit 1
            ;;
    esac
fi