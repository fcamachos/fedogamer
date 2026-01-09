#!/bin/bash

# =================================================================
# Gaming Setup Script Pro - Versión Estabilizada (Sudo Único)
# =================================================================

# Variable para identificar si ya estamos corriendo dentro de una terminal
INTERNAL_FLAG="$1"

# 1. DETECCIÓN DE DISTRIBUCIÓN
check_distro() {
    if [ -f /etc/fedora-release ]; then echo "fedora"
    elif [ -f /etc/debian_version ]; then echo "debian"
    elif [ -f /etc/arch-release ]; then echo "arch"
    else echo "unknown"; fi
}
DISTRO=$(check_distro)

# 2. LANZADOR DE TERMINAL Y AUTENTICACIÓN
# Si se hace doble click (no hay terminal) o si no se ha pasado el flag interno
if [ "$INTERNAL_FLAG" != "--child" ]; then
    for term in gnome-terminal konsole xfce4-terminal alacritty xterm; do
        if command -v $term >/dev/null 2>&1; then
            # Lanzamos la terminal y le pedimos que ejecute este mismo script con el flag --child
            exec $term -e bash "$0" --child
            exit 0
        fi
    done
    # Si no hay terminal disponible, intentamos seguir (podría fallar pkexec)
fi

# 3. INSTALACIÓN DE ZENITY Y SUDO (Dentro de la terminal ya abierta)
if [ "$INTERNAL_FLAG" == "--child" ]; then
    echo "=== Iniciando Entorno de Instalación ==="

    # Verificar Zenity
    if ! command -v zenity >/dev/null 2>&1; then
        echo "Instalando dependencia necesaria (zenity)..."
        case $DISTRO in
            fedora) sudo dnf install -y zenity ;;
            debian) sudo apt update && sudo apt install -y zenity ;;
            arch)   sudo pacman -S --needed --noconfirm zenity ;;
        esac
    fi

    # Pedir sudo una sola vez
    echo "Por favor, ingresa tu contraseña para autorizar la configuración:"
    if sudo -v; then
        # Mantener sudo vivo en segundo plano
        (while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done) 2>/dev/null &
        echo "Autenticación exitosa."
    else
        echo "Error de autenticación. Cerrando..."
        sleep 3
        exit 1
    fi
fi

# --- A PARTIR DE AQUÍ, ZENITY Y SUDO ESTÁN DISPONIBLES ---

PROGRESS_FIFO="/tmp/gaming_setup_$$.fifo"
CURRENT_USER=$(logname 2>/dev/null || echo "$USER")
TOTAL_STEPS=0
CURRENT_STEP=0

cleanup() {
    [ -e "$PROGRESS_FIFO" ] && rm -f "$PROGRESS_FIFO"
    exec 3>&- 2>/dev/null
    pkill -P $$ zenity 2>/dev/null
}
trap cleanup EXIT

start_progress_ui() {
    mkfifo "$PROGRESS_FIFO"
    exec 3<> "$PROGRESS_FIFO"
    zenity --progress --title="Gaming Setup" --text="Iniciando..." --percentage=0 --auto-close --width=450 --no-cancel <&3 &
}

update_ui() {
    local percent=$1
    local msg=$2
    echo "$percent" >&3
    echo "# $msg" >&3
    echo -e "[LOG] $percent% - $msg"
}

run_step() {
    local cmd=$1
    local desc=$2
    ((CURRENT_STEP++))
    local percent=$(( (CURRENT_STEP * 100) / TOTAL_STEPS ))
    update_ui "$percent" "$desc"

    # Ejecutamos con sudo (no pedirá clave por el keep-alive anterior)
    sudo bash -c "$cmd"
}

# --- INTERFAZ DE SELECCIÓN ---

if [ "$DISTRO" == "unknown" ]; then
    zenity --error --text="Distribución no soportada."
    exit 1
fi

SELECCION=$(zenity --list --checklist --width=700 --height=500 \
    --title="Configuración Gaming Linux" \
    --column="Selección" --column="ID" --column="Descripción" \
    TRUE "REPO" "Repositorios (RPM Fusion / Contrib / Multilib)" \
    TRUE "WINE" "Wine, Winetricks y dependencias de 32 bits" \
    TRUE "LUTRIS" "Instalar Lutris (Gestor de juegos)" \
    TRUE "DRIVERS" "Drivers Vulkan, Mesa y optimizaciones" \
    TRUE "STEAM" "Steam + Discord + Herramientas" \
    TRUE "CODECS" "Codecs Multimedia (MP4, MP3, etc.)" \
    --separator="|")

[ -z "$SELECCION" ] && exit 0

IFS="|" read -ra PASOS <<< "$SELECCION"
TOTAL_STEPS=${#PASOS[@]}

start_progress_ui

for opt in "${PASOS[@]}"; do
    case $opt in
        "REPO")
            case "$DISTRO" in
                fedora) run_step "dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-\$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-\$(rpm -E %fedora).noarch.rpm" "Habilitando RPM Fusion" ;;
                debian) run_step "sed -i 's/main\$/main contrib non-free non-free-firmware/' /etc/apt/sources.list && apt update" "Habilitando Contrib/Non-Free" ;;
                arch)   run_step "grep -q '^\[multilib\]' /etc/pacman.conf || (echo -e '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf && pacman -Sy)" "Habilitando Multilib" ;;
            esac ;;
        "WINE")
            case "$DISTRO" in
                fedora) run_step "dnf install -y wine winetricks glibc.i686" "Instalando Wine" ;;
                debian) run_step "dpkg --add-architecture i386 && apt update && apt install -y wine winetricks" "Instalando Wine" ;;
                arch)   run_step "pacman -S --needed --noconfirm wine winetricks lib32-glibc" "Instalando Wine" ;;
            esac ;;
        "LUTRIS")
            case "$DISTRO" in
                fedora) run_step "dnf install -y lutris" "Instalando Lutris" ;;
                debian) run_step "apt install -y lutris" "Instalando Lutris" ;;
                arch)   run_step "pacman -S --needed --noconfirm lutris" "Instalando Lutris" ;;
            esac ;;
        "DRIVERS")
            case "$DISTRO" in
                fedora) run_step "dnf install -y mesa-vulkan-drivers vulkan-loader gamemode mangohud" "Drivers/Optimización" ;;
                debian) run_step "apt install -y mesa-vulkan-drivers gamemode mangohud" "Drivers/Optimización" ;;
                arch)   run_step "pacman -S --needed --noconfirm vulkan-icd-loader lib32-vulkan-icd-loader gamemode mangohud" "Drivers/Optimización" ;;
            esac ;;
        "STEAM")
            case "$DISTRO" in
                fedora) run_step "dnf install -y steam discord" "Instalando Steam/Discord" ;;
                debian) run_step "apt install -y steam" "Instalando Steam" ;;
                arch)   run_step "pacman -S --needed --noconfirm steam discord" "Instalando Steam/Discord" ;;
            esac ;;
        "CODECS")
            case "$DISTRO" in
                fedora) run_step "dnf group upgrade --with-optional Multimedia -y && dnf install -y gstreamer1-libav ffmpeg" "Codecs Multimedia" ;;
                debian) run_step "apt install -y gstreamer1.0-plugins-bad gstreamer1.0-libav ffmpeg" "Codecs Multimedia" ;;
                arch)   run_step "pacman -S --needed --noconfirm ffmpeg gstreamer gst-libav" "Codecs Multimedia" ;;
            esac ;;
    esac
done

update_ui 100 "¡Instalación completa!"
sleep 2
zenity --info --title="Éxito" --text="El proceso ha terminado correctamente." --width=300
exit 0
