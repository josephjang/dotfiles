#!/bin/bash
# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# Color variables for script output
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'

# List of files and directories to exclude from rsync
EXCLUDE_FILES=(
    ".git/"
    ".git"
    ".DS_Store"
    "bootstrap.sh"
    "README.md"
    ".gitmodules"
)

# --- Function Definitions ---
# A single function to handle both dry-run and actual sync
function sync_files() {
    # Dynamically build the rsync exclude options from the array
    local rsync_exclude_opts=""
    for item in "${EXCLUDE_FILES[@]}"; do
        rsync_exclude_opts+="--exclude=$item "
    done
    
    echo -e "${C_YELLOW}Running rsync... (Source: $(pwd), Destination: ~)${C_RESET}"
    # $@ forwards all arguments passed to the function (e.g., --dry-run) to rsync
    rsync $rsync_exclude_opts --include ".**" --archive --verbose . ~ $@
}

# --- Main Logic ---
# Change directory to the script's location
cd "$(dirname "$0")"

echo -e "${C_GREEN}1. Updating the .dotfiles repository...${C_RESET}"
git pull
git submodule init
git submodule update

if [[ "$1" == "--force" || "$1" == "-f" ]]; then
    echo -e "${C_YELLOW}Force option detected. Proceeding with sync...${C_RESET}"
    sync_files
elif [[ "$1" == "--preview" || "$1" == "--dry-run" ]]; then
    echo -e "${C_GREEN}2. Previewing changes (dry-run)...${C_RESET}"
    sync_files --dry-run
    echo -e "${C_YELLOW}Preview complete. No files were changed.${C_RESET}"
else
    echo -e "${C_GREEN}2. Previewing changes (dry-run)...${C_RESET}"
    sync_files --dry-run
    
    echo # Newline for readability
    read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1 -r
    echo # Newline for readability
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${C_GREEN}3. Proceeding with the actual sync...${C_RESET}"
        sync_files
    else
        echo -e "${C_RED}Operation cancelled.${C_RESET}"
        exit 0
    fi
fi

echo -e "\n${C_GREEN}✨ Sync completed successfully.${C_RESET}"
echo "To apply changes, please restart your shell or run 'source ~/.zshrc' or 'source ~/.bash_profile'."