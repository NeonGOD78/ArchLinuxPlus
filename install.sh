#!/usr/bin/env -S bash -e

# Cleaning the TTY.
clear

# Cosmetics (colours for text).
BOLD='\e[1m'
BRED='\e[91m'
BBLUE='\e[34m'  
BGREEN='\e[92m'
BYELLOW='\e[93m'
RESET='\e[0m'

# Pretty print (function).
info_print () {
    echo -e "${BOLD}${BGREEN}[ ${BYELLOW}•${BGREEN} ] $1${RESET}"
}

# Pretty print for input (function).
input_print () {
    echo -ne "${BOLD}${BYELLOW}[ ${BGREEN}•${BYELLOW} ] $1${RESET}"
}

# Alert user of bad input (function).
error_print () {
    echo -e "${BOLD}${BRED}[ ${BBLUE}•${BRED} ] $1${RESET}"
}

# Virtualization check (function).
virt_check () {
    hypervisor=$(systemd-detect-virt)
    case $hypervisor in
        kvm )   info_print "KVM har været opdaget, opsætter gæstværktøjer."
                pacstrap /mnt qemu-guest-agent &>/dev/null
                systemctl enable qemu-guest-agent --root=/mnt &>/dev/null
                ;;
        vmware  )   info_print "VMWare Workstation/ESXi har været opdaget, opsætter gæstværktøjer."
                    pacstrap /mnt open-vm-tools >/dev/null
                    systemctl enable vmtoolsd --root=/mnt &>/dev/null
                    systemctl enable vmware-vmblock-fuse --root=/mnt &>/dev/null
                    ;;
        oracle )    info_print "VirtualBox har været opdaget, opsætter gæstværktøjer."
                    pacstrap /mnt virtualbox-guest-utils &>/dev/null
                    systemctl enable vboxservice --root=/mnt &>/dev/null
                    ;;
        microsoft ) info_print "Hyper-V har været opdaget, opsætter gæstværktøjer."
                    pacstrap /mnt hyperv &>/dev/null
                    systemctl enable hv_fcopy_daemon --root=/mnt &>/dev/null
                    systemctl enable hv_kvp_daemon --root=/mnt &>/dev/null
                    systemctl enable hv_vss_daemon --root=/mnt &>/dev/null
                    ;;
    esac
}

# Selecting a kernel to install (function).
kernel_selector () {
    info_print "Liste af kerner:"
    info_print "1) Stabil: Vanilla Linux-kerne med nogle Arch Linux patches"
    info_print "2) Hardened: En sikkerhedsorienteret Linux-kerne"
    info_print "3) Longterm: Langtidsstøtte (LTS) Linux-kerne"
    info_print "4) Zen Kernel: En Linux-kerne optimeret til desktopbrug"
    input_print "Vælg nummeret for den ønskede kerne (f.eks. 1): " 
    read -r kernel_choice
    case $kernel_choice in
        1 ) kernel="linux"
            return 0;;
        2 ) kernel="linux-hardened"
            return 0;;
        3 ) kernel="linux-lts"
            return 0;;
        4 ) kernel="linux-zen"
            return 0;;
        * ) error_print "Du har ikke indtastet et gyldigt valg, prøv igen."
            return 1
    esac
}

# Selecting a way to handle internet connection (function).
network_selector () {
    info_print "Netværksværktøjer:"
    info_print "1) IWD: Utility til at forbinde til netværk, skrevet af Intel (WiFi kun, indbygget DHCP klient)"
    info_print "2) NetworkManager: Universelt netværksværktøj (både WiFi og Ethernet, anbefales)"
    info_print "3) wpa_supplicant: Værktøj med støtte for WEP og WPA/WPA2 (WiFi kun, DHCPCD installeres automatisk)"
    info_print "4) dhcpcd: Grundlæggende DHCP-klient (Ethernet-forbindelser eller VMs)"
    info_print "5) Jeg gør dette selv (kun avancerede brugere)"
    input_print "Vælg nummeret for netværksværktøjet (f.eks. 1): "
    read -r network_choice
    if ! ((1 <= network_choice && network_choice <= 5)); then
        error_print "Du har ikke indtastet et gyldigt valg, prøv igen."
        return 1
    fi
    return 0
}

# Installing the chosen networking method to the system (function).
network_installer () {
    case $network_choice in
        1 ) info_print "Installerer og aktiverer IWD."
            pacstrap /mnt iwd >/dev/null
            systemctl enable iwd --root=/mnt &>/dev/null
            ;;
        2 ) info_print "Installerer og aktiverer NetworkManager."
            pacstrap /mnt networkmanager >/dev/null
            systemctl enable NetworkManager --root=/mnt &>/dev/null
            ;;
        3 ) info_print "Installerer og aktiverer wpa_supplicant og dhcpcd."
            pacstrap /mnt wpa_supplicant dhcpcd >/dev/null
            systemctl enable wpa_supplicant --root=/mnt &>/dev/null
            systemctl enable dhcpcd --root=/mnt &>/dev/null
            ;;
        4 ) info_print "Installerer dhcpcd."
            pacstrap /mnt dhcpcd >/dev/null
            systemctl enable dhcpcd --root=/mnt &>/dev/null
            ;;
    esac
}

# Sikkerhedsforanstaltning for LUKS-container og brugerindstillinger.
lukspass_selector () {
    input_print "Indtast venligst en adgangskode til LUKS containeren (du vil ikke kunne se adgangskoden): "
    read -r -s password
    if [[ -z "$password" ]]; then
        echo
        error_print "Du skal indtaste en adgangskode til LUKS containeren, prøv igen."
        return 1
    fi
    echo
    input_print "Indtast adgangskoden igen: "
    read -r -s password2
    echo
    if [[ "$password" != "$password2" ]]; then
        error_print "Adgangskoderne stemmer ikke overens, prøv igen."
        return 1
    fi
    return 0
}

# Root password (funktion).
rootpass_selector () {
    input_print "Indtast et root-adgangskode (du vil ikke kunne se adgangskoden): "
    read -r -s rootpass
    if [[ -z "$rootpass" ]]; then
        echo
        error_print "Root-adgangskoden kan ikke være tom, prøv igen."
        return 1
    fi
    echo
    input_print "Indtast root-adgangskoden igen: "
    read -r -s rootpass2
    echo
    if [[ "$rootpass" != "$rootpass2" ]]; then
        error_print "Root-adgangskoderne stemmer ikke overens, prøv igen."
        return 1
    fi
    return 0
}

# User creation (function).
user_creator () {
    input_print "Indtast dit brugernavn: "
    read -r username
    if [[ -z "$username" ]]; then
        error_print "Brugernavnet kan ikke være tomt, prøv igen."
        return 1
    fi
    useradd -m -G wheel "$username"
    input_print "Indtast adgangskode til bruger $username (du vil ikke kunne se adgangskoden): "
    read -r -s userpass
    if [[ -z "$userpass" ]]; then
        error_print "Brugeradgangskoden kan ikke være tom, prøv igen."
        return 1
    fi
    echo "$username:$userpass" | chpasswd
    echo "$username er blevet oprettet."
    return 0
}

# Selecting default editor (function).
editor_selector () {
    info_print "Vælg en standard editor:"
    info_print "1) Vim"
    info_print "2) Neovim"
    info_print "3) Emacs"
    info_print "4) Nano"
    info_print "5) Micro"
    input_print "Vælg nummeret for din ønskede editor (f.eks. 1): "
    read -r editor_choice
    case $editor_choice in
        1 ) editor="vim"
            ;;
        2 ) editor="neovim"
            ;;
        3 ) editor="emacs"
            ;;
        4 ) editor="nano"
            ;;
        5 ) editor="micro"
            ;;
        * ) error_print "Du har ikke indtastet et gyldigt valg, prøv igen."
            return 1
    esac
    # Opdatering af /etc/environment med den valgte editor
    echo "EDITOR=$editor" | tee -a /mnt/etc/environment >/dev/null
    info_print "Valgt editor $editor er nu sat som standard editor."
    return 0
}

# Install Yay (function).
yay_installer () {
    info_print "Installerer yay (AUR-hjælper)."
    pacstrap /mnt base-devel git >/dev/null
    arch-chroot /mnt bash -c 'cd /tmp && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm' &>/dev/null
    info_print "yay er nu installeret."
    return 0
}

# KDE installation (function).
kde_installer () {
    input_print "Vil du installere KDE med de ønskede pakker? (y/n): "
    read -r kde_choice
    if [[ "$kde_choice" =~ ^[Yy]$ ]]; then
        info_print "Installerer KDE med pakkerne..."
        pacstrap /mnt plasma-desktop plasma-firewall plasma-pa kitty mc kscreen kinfocenter dolphin plasma-wayland-protocols plasma-workspace-wallpapers sddm sddm-kcm oxygen breeze-gtk kde-gtk-config kvantum plasma-nm layer-shell-qt bluez bluez-utils ufw kwallet kwallet-pam kwalletmanager signon-kwallet-extension btrfs-assistant geany partitionmanager strawberry vlc okular putty waterfox xnviewmp &>/dev/null
        systemctl enable sddm --root=/mnt &>/dev/null
        info_print "KDE installation er færdig."
    else
        info_print "Ingen KDE-pakker blev installeret."
    fi
}

# Main Installation Script
main_installation () {
    # Kernel valg
    kernel_selector
    # Netværksværktøj valg
    network_selector
    # Luks password
    lukspass_selector
    # Root password
    rootpass_selector
    # Brugeroprettelse
    user_creator
    # Editor valg
    editor_selector
    # Installer yay
    yay_installer
    # KDE installation
    kde_installer
    # Installer og aktiver netværk
    network_installer
    # Installer kerne og opsætning
    pacstrap /mnt "$kernel" &>/dev/null
    virt_check
    # Installering af systemværktøjer (herunder grub)
    pacstrap /mnt grub os-prober efibootmgr &>/dev/null
    systemctl enable NetworkManager --root=/mnt &>/dev/null
    systemctl enable systemd-timesyncd --root=/mnt &>/dev/null
    info_print "Installation færdig!"
}

main_installation
