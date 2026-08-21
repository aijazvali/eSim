#!/bin/bash
#=============================================================================
#          FILE: install-eSim.sh
# 
#         USAGE: ./install-eSim.sh --install 
#                            OR
#                ./install-eSim.sh --uninstall
#                
#   DESCRIPTION: Installation script for eSim EDA Suite
#
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#       AUTHORS: Fahim Khan, Rahul Paknikar, Saurabh Bansode,
#                Sumanto Kar, Partha Singha Roy, Jayanth Tatineni,
#                Anshul Verma, Shiva Krishna Sangati, Harsha Narayana P
#  ORGANIZATION: eSim Team, FOSSEE, IIT Bombay
#       CREATED: Sunday 25 May 2025 17:40
#      REVISION: ---
#=============================================================================

# Function to detect Ubuntu version without depending on lsb_release.
get_ubuntu_version() {
    local os_release_file="${ESIM_OS_RELEASE_FILE:-/etc/os-release}"

    if [[ ! -r "$os_release_file" ]]; then
        echo "Unable to read Ubuntu release information: $os_release_file" >&2
        exit 1
    fi

    # shellcheck disable=SC1090
    source "$os_release_file"
    VERSION_ID="${VERSION_ID:-}"
    FULL_VERSION="${VERSION:-Ubuntu $VERSION_ID}"

    if [[ -z "$VERSION_ID" ]]; then
        echo "VERSION_ID is missing from $os_release_file" >&2
        exit 1
    fi

    echo "Detected Ubuntu Version: $FULL_VERSION"
}

# Function to choose and run the appropriate script
run_version_script() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install-eSim-scripts"
    
    # Decide script based on full version
    case $VERSION_ID in
        "22.04")
            if [[ "$FULL_VERSION" == "22.04.4" ]]; then
                SCRIPT="$SCRIPT_DIR/install-eSim-22.04.sh"
            else
                SCRIPT="$SCRIPT_DIR/install-eSim-23.04.sh"
            fi
            ;;
        "23.04")
            SCRIPT="$SCRIPT_DIR/install-eSim-23.04.sh"
            ;;
        "24.04")
            SCRIPT="$SCRIPT_DIR/install-eSim-24.04.sh"
            ;;
        "25.04")
            SCRIPT="$SCRIPT_DIR/install-eSim-24.04.sh"
            ;;
        *)
            echo "Unsupported Ubuntu version: $VERSION_ID ($FULL_VERSION)"
            exit 1
            ;;
    esac

    # Run the script if found
    if [[ -f "$SCRIPT" ]]; then
        echo "Running script: $SCRIPT $ARGUMENT"
        bash "$SCRIPT" "$ARGUMENT"
    else
        echo "Installation script not found: $SCRIPT"
        exit 1
    fi
}

# --- Main Execution Starts Here ---

# Validate argument
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 --install | --uninstall"
    exit 1
fi

ARGUMENT=$1
if [[ "$ARGUMENT" != "--install" && "$ARGUMENT" != "--uninstall" ]]; then
    echo "Invalid argument: $ARGUMENT"
    echo "Usage: $0 --install | --uninstall"
    exit 1
fi

get_ubuntu_version
run_version_script

