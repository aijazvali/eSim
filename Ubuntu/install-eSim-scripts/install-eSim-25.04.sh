#!/bin/bash 
#=============================================================================
#          FILE: install-eSim-25.04.sh
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
#                Sumanto Kar, Partha Singha Roy, Harsha Narayana P, 
#                Jayanth Tatineni, Anshul Verma
#       MENTORS: Sumanto Kar, Varad Patil, Shanti Priya K, Aditya M
#       INTERNS: Akshay Rukade, Haripriyan R
#  ORGANIZATION: eSim Team, FOSSEE, IIT Bombay
#       CREATED: Wednesday 15 July 2015 15:26
#      REVISION: Sunday 25 May 2025 17:40
#=============================================================================

# All variables goes here
config_dir="$HOME/.esim"
config_file="config.ini"
eSim_Home=`pwd`
ngspiceFlag=0
ubuntu_version=$(lsb_release -rs 2>/dev/null || awk -F= '/^VERSION_ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)

## All Functions goes here

error_exit()
{

    echo -e "\n\nError! Kindly resolve above error(s) and try again."
    echo -e "\nAborting Installation...\n"

}

function die
{
    echo -e "\nERROR: $1\n"
    exit 1
}


function isUbuntu2504
{
    [[ "$ubuntu_version" == "25.04" ]]
}


function useOldReleasesForUbuntu2504
{
    isUbuntu2504 || return 0

    echo "Ubuntu 25.04 is past standard support; checking apt archive URLs..."

    local source_files=(
        "/etc/apt/sources.list"
        "/etc/apt/sources.list.d/ubuntu.sources"
    )
    local source_file
    local changed=0

    for source_file in "${source_files[@]}"; do
        if [ ! -f "$source_file" ]; then
            continue
        fi

        if sudo grep -q "plucky" "$source_file"; then
            if ! sudo grep -q "old-releases.ubuntu.com" "$source_file"; then
                echo "Switching $source_file to old-releases.ubuntu.com for Ubuntu 25.04."
                if [ ! -f "$source_file.esim-backup" ]; then
                    sudo cp -a "$source_file" "$source_file.esim-backup"
                fi
                sudo sed -i -E \
                    -e 's|https?://([A-Za-z0-9.-]+\.)?archive\.ubuntu\.com/ubuntu/?|http://old-releases.ubuntu.com/ubuntu/|g' \
                    -e 's|https?://security\.ubuntu\.com/ubuntu/?|http://old-releases.ubuntu.com/ubuntu/|g' \
                    "$source_file"
                changed=1
            fi
        fi
    done

    if [ "$changed" -eq 0 ]; then
        echo "No Ubuntu 25.04 archive URL changes were needed."
    fi
}


function oldReleasesHasUbuntu2504
{
    python3 - <<'PY'
import sys
import urllib.request

try:
    response = urllib.request.urlopen(
        "http://old-releases.ubuntu.com/ubuntu/dists/plucky/Release",
        timeout=10,
    )
except Exception:
    sys.exit(1)

sys.exit(0 if response.status < 400 else 1)
PY
}


function aptUpdate
{
    local apt_log
    apt_log=$(mktemp)

    if sudo apt-get update >"$apt_log" 2>&1; then
        cat "$apt_log"
        rm -f "$apt_log"
        return 0
    fi

    cat "$apt_log"

    if isUbuntu2504 && grep -Eiq '(archive|security).*ubuntu\.com/ubuntu.*plucky|plucky.*(archive|security).*ubuntu\.com/ubuntu' "$apt_log"; then
        rm -f "$apt_log"
        if oldReleasesHasUbuntu2504; then
            useOldReleasesForUbuntu2504
            sudo apt-get update
            return $?
        fi

        echo "Ubuntu 25.04 archive update failed, but old-releases.ubuntu.com does not currently provide plucky packages."
        return 1
    fi

    rm -f "$apt_log"
    return 1
}


function ensureAddAptRepository
{
    if ! command -v add-apt-repository >/dev/null 2>&1; then
        echo "Installing software-properties-common for add-apt-repository..."
        aptUpdate
        sudo apt-get install -y software-properties-common
    fi
}


function enableUniverse
{
    ensureAddAptRepository
    sudo add-apt-repository -y -n universe
}


function disableKicadPpasForUbuntu2504
{
    isUbuntu2504 || return 0

    local source_file
    local main_sources="/etc/apt/sources.list"

    if [ -f "$main_sources" ] && sudo grep -qiE 'ppa\.launchpad(content)?\.net/kicad|kicad-[0-9._-]+-releases' "$main_sources"; then
        echo "Disabling stale KiCad PPA entries in $main_sources for Ubuntu 25.04."
        if [ ! -f "$main_sources.esim-backup" ]; then
            sudo cp -a "$main_sources" "$main_sources.esim-backup"
        fi
        sudo sed -i -E '/ppa\.launchpad(content)?\.net\/kicad|kicad-[0-9._-]+-releases/ {/^[[:space:]]*#/! s|^|# disabled by eSim for Ubuntu 25.04: |}' "$main_sources"
    fi

    shopt -s nullglob
    for source_file in /etc/apt/sources.list.d/*kicad*.list /etc/apt/sources.list.d/*kicad*.sources; do
        if [[ "$source_file" == *.disabled-by-esim ]]; then
            continue
        fi

        echo "Disabling stale KiCad PPA source for Ubuntu 25.04: $source_file"
        sudo mv "$source_file" "$source_file.disabled-by-esim"
    done
    shopt -u nullglob
}


function aptPackageHasCandidate
{
    local package_name="$1"
    local candidate

    candidate=$(apt-cache policy "$package_name" | awk '/Candidate:/ {print $2; exit}')
    [[ -n "$candidate" && "$candidate" != "(none)" ]]
}


function preflightInstallPayload
{
    local missing=0
    local required_path
    local required_paths=(
        "nghdl.zip"
        "library/kicadLibrary.tar.xz"
        "images/logo.png"
        "src/frontEnd/Application.py"
    )

    for required_path in "${required_paths[@]}"; do
        if [ ! -e "$required_path" ]; then
            echo "Missing required installer payload: $required_path"
            missing=1
        fi
    done

    if [ "$missing" -ne 0 ]; then
        die "Run the installer from a complete eSim release directory. The installer-only branch does not contain the runtime payload files listed above."
    fi
}


function createConfigFile
{

    # Creating config.ini file and adding configuration information
    mkdir -p "$config_dir"
    : > "$config_dir/$config_file"
    
    echo "[eSim]" >> "$config_dir/$config_file"
    echo "eSim_HOME = $eSim_Home" >> "$config_dir/$config_file"
    echo "LICENSE = %(eSim_HOME)s/LICENSE" >> "$config_dir/$config_file"
    echo "KicadLib = %(eSim_HOME)s/library/kicadLibrary.tar.xz" >> "$config_dir/$config_file"
    echo "IMAGES = %(eSim_HOME)s/images" >> "$config_dir/$config_file"
    echo "VERSION = %(eSim_HOME)s/VERSION" >> "$config_dir/$config_file"
    echo "MODELICA_MAP_JSON = %(eSim_HOME)s/library/ngspicetoModelica/Mapping.json" >> "$config_dir/$config_file"
   
}


function installNghdl
{

    echo "Installing NGHDL..........................."
    rm -rf nghdl
    unzip -o nghdl.zip

    if [ ! -f "nghdl/install-nghdl.sh" ]; then
        die "nghdl.zip did not extract the expected nghdl/install-nghdl.sh script."
    fi

    prepareNghdlForUbuntu2504

    cd nghdl/
    chmod +x install-nghdl.sh install-nghdl-scripts/*.sh

    # Do not trap on error of any command. Let NGHDL script handle its own errors.
    trap "" ERR

    if isUbuntu2504; then
        ./install-nghdl-scripts/install-nghdl-25.04.sh --install
    else
        ./install-nghdl.sh --install       # Install NGHDL
    fi
        
    # Set trap again to error_exit function to exit on errors
    trap error_exit ERR

    ngspiceFlag=1
    cd ../

}


function prepareNghdlForUbuntu2504
{
    isUbuntu2504 || return 0

    local scripts_dir="nghdl/install-nghdl-scripts"
    local source_script="$scripts_dir/install-nghdl-24.04.sh"
    local target_script="$scripts_dir/install-nghdl-25.04.sh"

    if [ ! -f "$source_script" ] && [ ! -f "$target_script" ]; then
        die "nghdl.zip does not contain an Ubuntu 24.04 or 25.04 NGHDL installer script."
    fi

    if [ ! -f "$target_script" ]; then
        echo "Adding Ubuntu 25.04 NGHDL installer entry point from the 24.04 script."
        cp "$source_script" "$target_script"
    fi

    echo "Patching NGHDL installer for Ubuntu 25.04 packages."
    perl -0pi -e '
        s/\bpython3-distutils\b/python3-setuptools/g;
        s/\blibcanberra-gtk-module\s+//g;
        s/\blibcanberra-gtk-module\b/libcanberra-gtk3-module/g;
        s/--with-llvm-config(?!-)(=\S+)?/--with-llvm-config=\/usr\/bin\/llvm-config-18/g;
        s/(?<!--with-)\bllvm-config\b(?!-18)/llvm-config-18/g;
        s/\bllvm-dev\b/llvm-18-dev/g;
        s/\bllvm\b(?!-)/llvm-18/g;
        s/\bclang\b(?!-)/clang-18/g;
    ' "$target_script"

    enableUniverse
    aptUpdate
    sudo apt-get install -y llvm-18 llvm-18-dev clang-18 libcanberra-gtk3-module python3-setuptools
}


function installSky130Pdk
{

    echo "Installing SKY130 PDK......................"

    local sky130_version="0fe599b2afb6708d281543108caf8310912f54af"
    local pdk_root="$config_dir/volare-pdk"
    local sky130_source="$pdk_root/volare/sky130/versions/$sky130_version/sky130A/libs.ref/sky130_fd_pr"

    if [ -d "/usr/share/local/sky130_fd_pr" ]; then
        echo "SKY130 PDK is already installed. Skipping download."
        return 0
    fi

    rm -rf "$pdk_root"
    mkdir -p "$pdk_root"

    # Install into a user-writable staging directory, then copy with sudo.
    volare enable --pdk sky130 --pdk-root "$pdk_root" "$sky130_version"

    if [ ! -d "$sky130_source" ]; then
        die "Volare completed, but the expected SKY130 library was not found at $sky130_source."
    fi

    # Copy SKY130 library
    echo "Copying SKY130 PDK........................."

    sudo mkdir -p /usr/share/local/
    sudo cp -a "$sky130_source" /usr/share/local/
    rm -rf "$pdk_root"

    # Change ownership from root to the user
    sudo chown -R "$USER:$USER" /usr/share/local/sky130_fd_pr/

}

function installIhpPdk
{
    echo -n "Do you want to install IHP Open PDK for analog IC design? (y/n): "
    read installIhp
    
    if [ "$installIhp" == "y" -o "$installIhp" == "Y" ]; then
        echo "Installing IHP Open PDK........................"
        
        if [ -f "ihp/ihp-install-script.sh" ]; then
            cd ihp/
            chmod +x ihp-install-script.sh
            trap "" ERR
            ./ihp-install-script.sh --install
            trap error_exit ERR
            cd ../
        else
            echo "IHP install script not found. Skipping..."
        fi
    else
        echo "Skipping IHP Open PDK installation"
    fi
}


function installKicad
{
    echo "Installing KiCad..........................."

    # Define KiCad PPAs based on Ubuntu version
    if [[ "$ubuntu_version" == "24.04" ]]; then
        echo "Ubuntu 24.04 detected."
        kicadppa="kicad/kicad-8.0-releases"
        kicadppa_name="${kicadppa#kicad/}"

        # Check if KiCad is installed using dpkg-query for the main package
        if dpkg -s kicad &>/dev/null; then
            installed_version=$(dpkg-query -W -f='${Version}' kicad | cut -d'.' -f1)
            if [[ "$installed_version" != "8" ]]; then
                echo "A different version of KiCad ($installed_version) is installed."
                read -p "Do you want to remove it and install KiCad 8.0? (yes/no): " response

                if [[ "$response" =~ ^([Yy][Ee][Ss]|[Yy])$ ]]; then
                    echo "Removing KiCad $installed_version..."
                    sudo apt-get remove --purge -y kicad kicad-footprints kicad-libraries kicad-symbols kicad-templates
                    sudo apt-get autoremove -y
                else
                    echo "Exiting installation. KiCad $installed_version remains installed."
                    exit 1
                fi
            else
                echo "KiCad 8.0 is already installed. Verifying support packages..."
            fi
        fi
    elif [[ "$ubuntu_version" == "25.04" ]]; then
        echo "Ubuntu 25.04 detected."
        echo "Using distro KiCad package instead of PPA due to libgit2 dependency mismatch."
        disableKicadPpasForUbuntu2504
        enableUniverse
        aptUpdate

        if ! aptPackageHasCandidate kicad; then
            die "No installable KiCad package was found in the Ubuntu 25.04 apt sources. Check that Ubuntu universe is enabled and apt sources point to a valid plucky archive."
        fi

        sudo apt-get install -y --no-install-recommends kicad kicad-footprints kicad-libraries kicad-symbols kicad-templates
        echo "KiCad installation completed successfully!"
        return 0
    
    
    else
        kicadppa="kicad/kicad-6.0-releases"
        kicadppa_name="${kicadppa#kicad/}"
    fi

    # Check if the PPA is already added
    if ! grep -Rqs "$kicadppa_name" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
        echo "Adding KiCad PPA to local apt repository: $kicadppa"
        ensureAddAptRepository
        sudo add-apt-repository -y "ppa:$kicadppa"
        aptUpdate
    else
        echo "KiCad PPA is already present in sources."
    fi

    # Install KiCad packages
    sudo apt-get install -y --no-install-recommends kicad kicad-footprints kicad-libraries kicad-symbols kicad-templates

    echo "KiCad installation completed successfully!"
}


function installDependency
{
    if isUbuntu2504; then
        disableKicadPpasForUbuntu2504
        enableUniverse
    fi

    echo "Updating apt index files..................."
    aptUpdate
    
    echo "Installing Python and application packages......................."
    sudo apt-get install -y \
        ca-certificates \
        python3-venv \
        python3-pip \
        python3-setuptools \
        python3-psutil \
        python3-pyqt5 \
        python3-matplotlib \
        unzip \
        xterm \
        xz-utils
   
    if [ -x "$config_dir/env/bin/python" ] && grep -q "include-system-site-packages = true" "$config_dir/env/pyvenv.cfg" 2>/dev/null; then
        echo "Reusing existing virtual environment at $config_dir/env"
    else
        echo "Creating virtual environment to isolate packages "
        rm -rf "$config_dir/env"
        python3 -m venv --system-site-packages "$config_dir/env"
    fi
    
    echo "Starting the virtual env..................."
    source "$config_dir/env/bin/activate"

    echo "Upgrading Pip.............................."
    python -m pip install --upgrade pip setuptools wheel

    echo "Installing Watchdog........................"
    python -m pip install watchdog

    echo "Installing Hdlparse........................"
    python -m pip install --upgrade https://github.com/hdl/pyhdlparser/tarball/master

    echo "Installing Makerchip......................."
    python -m pip install makerchip-app

    echo "Installing SandPiper Saas.................."
    python -m pip install sandpiper-saas

    echo "Installing volare.........................."
    python -m pip install volare
}


function copyKicadLibrary
{

    #Extract custom KiCad Library
    rm -rf kicadLibrary
    tar -xJf library/kicadLibrary.tar.xz

    if [ ! -d "kicadLibrary/template" ] || [ ! -d "kicadLibrary/eSim-symbols" ]; then
        die "library/kicadLibrary.tar.xz did not contain the expected KiCad template and eSim-symbols directories."
    fi

    local kicad_config_dir="$HOME/.config/kicad"
    local latest_version
    latest_version=$(find "$kicad_config_dir" -maxdepth 1 -mindepth 1 -type d -printf "%f\n" 2>/dev/null | grep -E "^[0-9]+\.[0-9]+$" | sort -V | tail -n 1)

    if [ -z "$latest_version" ]; then
        latest_version="8.0"
        echo ".config/kicad/$latest_version does not exist"
        mkdir -p "$kicad_config_dir/$latest_version"
    else
        echo "Using KiCad config folder: $kicad_config_dir/$latest_version"
    fi

    # Copy symbol table for eSim custom symbols 
    cp kicadLibrary/template/sym-lib-table "$kicad_config_dir/$latest_version/"
    echo "symbol table copied in the directory"

    # Copy KiCad symbols made for eSim
    sudo mkdir -p /usr/share/kicad/symbols/
    sudo cp -r kicadLibrary/eSim-symbols/. /usr/share/kicad/symbols/

    set +e      # Temporary disable exit on error
    trap "" ERR # Do not trap on error of any command
    
    # Remove extracted KiCad Library - not needed anymore
    rm -rf kicadLibrary

    set -e      # Re-enable exit on error
    trap error_exit ERR

    #Change ownership from Root to the User
    sudo chown -R "$USER:$USER" /usr/share/kicad/symbols/

}


function createDesktopStartScript
{    

    # Generating new esim-start.sh
    echo '#!/bin/bash' > esim-start.sh
    echo "cd \"$eSim_Home/src/frontEnd\" || exit 1" >> esim-start.sh
    echo "source \"$config_dir/env/bin/activate\"" >> esim-start.sh
    echo "python3 Application.py" >> esim-start.sh

    # Make it executable
    sudo chmod 755 esim-start.sh
    # Copy esim start script
    sudo cp -vp esim-start.sh /usr/bin/esim
    # Remove local copy of esim start script
    rm esim-start.sh

    # Generating esim.desktop file
    echo "[Desktop Entry]" > esim.desktop
    echo "Version=1.0" >> esim.desktop
    echo "Name=eSim" >> esim.desktop
    echo "Comment=EDA Tool" >> esim.desktop
    echo "GenericName=eSim" >> esim.desktop
    echo "Keywords=eda-tools" >> esim.desktop
    echo "Exec=esim %u" >> esim.desktop
    echo "Terminal=true" >> esim.desktop
    echo "X-MultipleArgs=false" >> esim.desktop
    echo "Type=Application" >> esim.desktop
    getIcon="$config_dir/logo.png"
    echo "Icon=$getIcon" >> esim.desktop
    echo "Categories=Development;" >> esim.desktop
    echo "MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/rss+xml;application/rdf+xml;image/gif;image/jpeg;image/png;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;x-scheme-handler/chrome;video/webm;application/x-xpinstall;" >> esim.desktop
    echo "StartupNotify=true" >> esim.desktop

    # Make esim.desktop file executable
    sudo chmod 755 esim.desktop
    # Copy desktop icon file to share applications
    sudo cp -vp esim.desktop /usr/share/applications/
    # Copy desktop icon file to Desktop
    mkdir -p "$HOME/Desktop"
    cp -vp esim.desktop "$HOME/Desktop/"

    set +e      # Temporary disable exit on error
    trap "" ERR # Do not trap on error of any command

    # Make esim.desktop file as trusted application
    gio set "$HOME/Desktop/esim.desktop" "metadata::trusted" true
    # Set Permission and Execution bit
    chmod a+x "$HOME/Desktop/esim.desktop"

    # Remove local copy of esim.desktop file
    rm esim.desktop

    set -e      # Re-enable exit on error
    trap error_exit ERR

    # Copying logo.png to .esim directory to access as icon
    cp -vp images/logo.png "$config_dir"

}


####################################################################
#                   MAIN START FROM HERE                           #
####################################################################

### Checking if file is passsed as argument to script

if [ "$#" -eq 1 ];then
    option=$1
else
    echo "USAGE : "
    echo "./install-eSim.sh --install"
    echo "./install-eSim.sh --uninstall"
    exit 1;
fi

## Checking flags

if [ "$option" == "--install" ];then

    set -e  # Set exit option immediately on error
    set -E  # inherit ERR trap by shell functions

    # Trap on function error_exit before exiting on error
    trap error_exit ERR


    echo "Enter proxy details if you are connected to internet thorugh proxy"
    
    echo -n "Is your internet connection behind proxy? (y/n): "
    read getProxy
    if [ "$getProxy" == "y" -o "$getProxy" == "Y" ];then
        echo -n 'Proxy Hostname :'
        read proxyHostname

        echo -n 'Proxy Port :'
        read proxyPort

        echo -n username@$proxyHostname:$proxyPort :
        read username

        echo -n 'Password :'
        read -s passwd

        unset http_proxy
        unset https_proxy
        unset HTTP_PROXY
        unset HTTPS_PROXY
        unset ftp_proxy
        unset FTP_PROXY

        export http_proxy=http://$username:$passwd@$proxyHostname:$proxyPort
        export https_proxy=http://$username:$passwd@$proxyHostname:$proxyPort
        export https_proxy=http://$username:$passwd@$proxyHostname:$proxyPort
        export HTTP_PROXY=http://$username:$passwd@$proxyHostname:$proxyPort
        export HTTPS_PROXY=http://$username:$passwd@$proxyHostname:$proxyPort
        export ftp_proxy=http://$username:$passwd@$proxyHostname:$proxyPort
        export FTP_PROXY=http://$username:$passwd@$proxyHostname:$proxyPort

        echo "Install with proxy"

    elif [ "$getProxy" == "n" -o "$getProxy" == "N" ];then
        echo "Install without proxy"
    
    else
        echo "Please select the right option"
        exit 0    
    fi

    # Calling functions
    preflightInstallPayload
    createConfigFile
    installDependency
    installKicad
    copyKicadLibrary
    installNghdl
    installSky130Pdk
    installIhpPdk
    createDesktopStartScript

    if [ $? -ne 0 ];then
        echo -e "\n\n\nERROR: Unable to install required packages. Please check your internet connection.\n\n"
        exit 0
    fi

    echo "-----------------eSim Installed Successfully-----------------"
    echo "Type \"esim\" in Terminal to launch it"
    echo "or double click on \"eSim\" icon placed on Desktop"


elif [ "$option" == "--uninstall" ];then
    echo -n "Are you sure? It will remove eSim completely including KiCad, Makerchip, NGHDL and SKY130 PDK along with their models and libraries (y/n):"
    read getConfirmation
    if [ "$getConfirmation" == "y" -o "$getConfirmation" == "Y" ];then
        echo "Removing eSim............................"
        sudo rm -rf "$HOME/.esim" "$HOME/Desktop/esim.desktop" /usr/bin/esim /usr/share/applications/esim.desktop
        echo "Removing KiCad..........................."
        sudo apt purge -y kicad kicad-footprints kicad-libraries kicad-symbols kicad-templates
        sudo rm -rf /usr/share/kicad
	sudo rm -f /etc/apt/sources.list.d/kicad*
        rm -rf "$HOME/.config/kicad/6.0" "$HOME/.config/kicad/8.0"

        echo "Removing Virtual env......................."
        sudo rm -rf "$config_dir/env"

        echo "Removing SKY130 PDK......................"
        sudo rm -rf /usr/share/local/sky130_fd_pr "$config_dir/volare-pdk"

        echo "Removing IHP Open PDK...................."
        if [ -f "ihp/install-ihp-openpdk.sh" ]; then
            cd ihp/
            chmod +x install-ihp-openpdk.sh
            ./install-ihp-openpdk.sh --uninstall
            cd ../
        fi

        echo "Removing NGHDL..........................."
        rm -rf library/modelParamXML/Nghdl/*
        rm -rf library/modelParamXML/Ngveri/*
        cd nghdl/
        if [ $? -eq 0 ];then
        	chmod +x install-nghdl.sh
    	    ./install-nghdl.sh --uninstall
    	    cd ../
    	    rm -rf nghdl
            if [ $? -eq 0 ];then
                echo -e "----------------eSim Uninstalled Successfully----------------"
            else
                echo -e "\nError while removing some files/directories in \"nghdl\". Please remove it manually"
            fi
        else
            echo -e "\nCannot find \"nghdl\" directory. Please remove it manually"
        fi
    elif [ "$getConfirmation" == "n" -o "$getConfirmation" == "N" ];then
        exit 0
    else 
        echo "Please select the right option."
        exit 0
    fi

else 
    echo "Please select the proper operation."
    echo "--install"
    echo "--uninstall"
fi
