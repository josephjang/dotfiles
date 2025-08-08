#!/bin/bash
# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# Color variables for script output
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'

# List of PATHS to exclude (matches the full path from root)
# This is for excluding the contents of the main .git directory.
EXCLUDE_PATHS=(
    "./.git/*"
)

# List of file NAMES to exclude (matches the basename anywhere in the tree)
# Added ".git" here to handle submodule gitfiles.
EXCLUDE_NAMES=(
    ".git"
    ".DS_Store"
    "bootstrap.sh"
    "README.md"
    ".gitmodules"
    "dotfiles_status.sh"
)

# --- Main Logic ---
echo -e "${C_GREEN}Starting smart check of .dotfiles...${C_RESET}"
echo "Mode: Comparing .dotfiles (Source) vs Home Directory (Destination)"
echo "==================================================================="

has_changes=false

# Get submodule paths to distinguish file types later
submodule_paths=()
if [ -f ".gitmodules" ]; then
    while read -r line; do
        submodule_paths+=("$line")
    done < <(git config --file .gitmodules --get-regexp path | awk '{ print $2 }')
fi

# Build find command arguments in an array to avoid word splitting issues
find_command_args=(".") # Start with the search path
find_command_args+=("-type" "f") # Find only files

# Add path-based exclusions
for pattern in "${EXCLUDE_PATHS[@]}"; do
    find_command_args+=("-not" "-path" "$pattern")
done
# Add name-based exclusions
for name in "${EXCLUDE_NAMES[@]}"; do
    find_command_args+=("-not" "-name" "$name")
done

# Use the array to execute find. The "${array[@]}" syntax is crucial.
find "${find_command_args[@]}" | while read -r dotfile_path; do
    # Remove the leading './' to get a clean relative path
    relative_path="${dotfile_path#./}"
    home_file_path="$HOME/$relative_path"

    # --- 1. Identify File Type (Regular vs. Submodule) ---
    is_submodule_file=false
    for sm_path in "${submodule_paths[@]}"; do
        if [[ "$relative_path" == "$sm_path"* ]]; then
            is_submodule_file=true
            break
        fi
    done

    # --- 2. Perform Checks ---
    if [ ! -f "$home_file_path" ]; then
        echo -e "➕ ${C_GREEN}[New File] Should be created at ~/${relative_path}${C_RESET}"
        has_changes=true
        continue
    fi

    if $is_submodule_file; then
        # For submodule files, check timestamp
        if [[ "$(uname)" == "Darwin" ]]; then # macOS
            dotfile_ts=$(stat -f %m "$dotfile_path")
            home_ts=$(stat -f %m "$home_file_path")
        else # Linux
            dotfile_ts=$(stat -c %Y "$dotfile_path")
            home_ts=$(stat -c %Y "$home_file_path")
        fi

        if [ "$dotfile_ts" -gt "$home_ts" ]; then
            echo -e "🔄 ${C_YELLOW}[Update Needed] Newer version in .dotfiles: ${relative_path}${C_RESET}"
            has_changes=true
        fi
    else
        # For regular files, check content diff
        if ! diff -q "$dotfile_path" "$home_file_path" > /dev/null; then
             echo -e "📝 ${C_BLUE}[Content Differs] Changes detected in: ${relative_path}${C_RESET}"
             has_changes=true
        fi
    fi
done

# --- Final Result ---
echo "==================================================================="
if ! $has_changes; then
    echo -e "🎉 ${C_GREEN}All synced! Your home directory is up-to-date with your .dotfiles.${C_RESET}"
else
    echo -e "🔍 ${C_YELLOW}Found differences. Run your bootstrap script to sync files.${C_RESET}"
fi
