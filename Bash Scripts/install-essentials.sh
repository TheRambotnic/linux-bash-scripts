#!/bin/bash

# Text colors
readonly CLR_DEFAULT="\033[1;0m"
readonly CLR_RED="\033[1;31m"
readonly CLR_YELLOW="\033[1;33m"
readonly CLR_GREEN="\033[1;32m"
readonly CLR_CYAN="\033[1;36m"

declare -A DNF_PACKAGES=(
    ["git"]="Git"
    ["zsh"]="Zsh"
    ["fzf"]="fzf"
    ["curl"]="curl"
    ["fastfetch"]="Fastfetch"
    ["btop"]="btop++"
    ["qdirstat"]="QDirStat"
    ["bleachbit"]="BleachBit"
    ["qalculate-qt"]="Qalculate! (Qt)"
    ["vlc"]="VLC media player"
    ["mpv"]="mpv Media Player"
    ["libavcodec-freeworld"]="Multimedia Codecs"
    ["gimp"]="GNU Image Manipulation Program (GIMP)"
    ["audacity"]="Audacity"
    ["easytag"]="EasyTAG"
    ["openrgb"]="OpenRGB"
    ["mangohud"]="MangoHud"
    ["goverlay"]="Goverlay"
    ["discord"]="Discord"
    ["steam"]="Steam"
    ["virt-manager"]="Virtual Machine Manager"
    ["kolourpaint"]="KolourPaint"
    ["scrcpy"]="scrcpy"
)

readonly DNF_PACKAGES

readonly COPR_REPOS=(
    "zeno/scrcpy"
)

declare -A FLATPAKS=(
    ["io.github.kolunmi.Bazaar"]="Bazaar"
    ["it.mijorus.gearlever"]="Gear Lever"
    ["io.github.seadve.Mousai"]="Mousai"
    ["org.nickvision.tubeconverter"]="Parabolic"
    ["com.vysp3r.ProtonPlus"]="ProtonPlus"
)

readonly FLATPAKS

# Utility functions
logHeader() {
    echo -e "\n${CLR_YELLOW} > $1 "
    echo -e "-----------------------------------${CLR_DEFAULT}"
}

logSuccess() {
    echo -e "${CLR_GREEN}$1${CLR_DEFAULT}"
}

logInfo() {
    echo -e "\n${CLR_CYAN}$1${CLR_DEFAULT}"
}

logError() {
    echo -e "${CLR_RED}$1${CLR_DEFAULT}"
}

beginInstallation() {
    setupRepositories
    installSystemPackages
    installCurlPackages
    installFlatpaks
    installGraphicsDrivers
    configureSystem
    restartSession
}

setupRepositories() {
    logHeader "Configuring repositories"

    for repo in "${COPR_REPOS[@]}"; do
        logInfo ">>> Enabling COPR: $repo"
        sudo dnf copr enable -y "$repo"
    done

    logInfo ">>> Enabling Flathub"
    flatpak remote-delete fedora && flatpak remote-delete fedora-testing
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

    logInfo ">>> Enabling RPM Fusion"
    sudo dnf install -y \
        https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
}

installSystemPackages() {
    logHeader "Running system upgrade"
    sudo dnf upgrade -y

    logHeader "Installing system packages"

    for pkg in "${!DNF_PACKAGES[@]}"; do
        if rpm -q $pkg &>/dev/null; then
            logSuccess "> ${DNF_PACKAGES[$pkg]} already installed"
        else
            logInfo ">>> Installing ${DNF_PACKAGES[$pkg]}"
            sudo dnf install $pkg -y
        fi
    done
}

installCurlPackages() {
    logHeader "Installing external packages (curl)"

    logInfo ">>> Installing Brave Browser"
    curl -fsS https://dl.brave.com/install.sh | sh

    logInfo ">>> Installing Zoxide"
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh

    logInfo ">>> Installing Zed"
    curl -f https://zed.dev/install.sh | sh
}

installFlatpaks() {
    logHeader "Installing Flatpaks"

    for pkg in "${!FLATPAKS[@]}"; do
        logInfo ">>> Installing ${FLATPAKS[$pkg]}"
        flatpak install flathub "$pkg" -y
    done
}

installGraphicsDrivers() {
    logHeader "Checking graphics drivers"

    local gpuInfo=$(lspci | grep -i vga)
    local nvidiaDrivers=akmod-nvidia
    local amdDrivers=mesa-vulkan-drivers

    if [[ $gpuInfo == *"NVIDIA Corporation"* ]]; then
        # For reference: https://rpmfusion.org/Howto/NVIDIA
        logInfo "NVIDIA GPU detected.\n"

        if rpm -q $nvidiaDrivers &>/dev/null; then
            logSuccess "> NVIDIA drivers already installed"
        else
            logInfo ">>> Installing NVIDIA drivers..."
            sudo dnf install $nvidiaDrivers -y

            logInfo "Waiting for kernel module build (do not close)..."

            while ! modinfo -F version nvidia &>/dev/null; do
                sleep 10
                echo -n "."
            done

            logSuccess "NVIDIA drivers ready"
        fi
    elif [[ $gpu_info == *"Advanced Micro Devices"* ]]; then
        # AMD drivers are included in Fedora by default, but might as well double check
        logInfo "AMD GPU detected."

        if rpm -q $amdDrivers &>/dev/null; then
            logSuccess "> AMD Vulkan drivers already installed"
        else
            logInfo ">>> Installing AMD Vulkan drivers..."
            sudo dnf install $amdDrivers -y
        fi
    else
        logError "No NVIDIA or AMD GPU detected."
    fi
}

configureSystem() {
    logHeader "Applying system configurations"

    # # Move custom zsh files to the correct directory
    # mv ../Shell\ Configs/.zsh* ~/

    logInfo ">>> Setting zsh as default shell"
    local username=$(whoami)
    local zshDir=$(which zsh)
    sudo sed -i -e "s|root:/bin/bash|root:$zshDir|g" -e "s|$username:/bin/bash|$username:$zshDir|g" /etc/passwd

    logInfo ">>> Enabling virtualization"
    sudo systemctl enable --now libvirtd
    sudo usermod -a -G libvirt $USER

    logInfo ">>> Cleaning up dependencies"
    sudo dnf autoremove -y
    sudo dnf clean all
}

restartSession() {
    logSuccess "\nFINISHED! :)\n"
    echo -e "${CLR_YELLOW}NOTE:${CLR_DEFAULT} Some settings require a session restart to take effect."

    while true; do
        read -p "Would you like to restart your session now? [Y/n]: " yn
        yn=${yn:-y}

        case $yn in
            [Nn]* ) exit;;
            [Yy]* ) sudo pkill -KILL -u $(whoami);;
            * ) logError "\nPlease select YES (Y) or NO (N).";;
        esac
    done
}

setTitle() {
    echo -e "\033]2;Essential system packages for Fedora\007"
}

main() {
    clear
    setTitle

    echo "This script will install essential packages on your computer and requires administrative (sudo) permissions."
    echo -e "${CLR_YELLOW}NOTICE:${CLR_DEFAULT} Running scripts from the internet can be dangerous. Please ensure you have audited and trust this script's code before proceeding.\n"

    while true; do
        read -p "Do you wish to continue? [y/N]: " yn
        yn=${yn:-n}

        case $yn in
            [Nn]* ) exit;;
            [Yy]* ) beginInstallation;;
            * ) logError "\nPlease select YES (Y) or NO (N).";;
        esac
    done
}

main
