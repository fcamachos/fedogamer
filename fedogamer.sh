#!/bin/bash

# =================================================================
# FedoGamer Script 
# =================================================================

# 1. Asegurar entorno gráfico
export DISPLAY=${DISPLAY:-:0}

# 2. Detección de Distribución (Necesaria para instalar Zenity si falta)
check_distro() {
    if [ -f /etc/fedora-release ]; then echo "fedora"
    elif [ -f /etc/debian_version ]; then echo "debian"
    elif [ -f /etc/arch-release ]; then echo "arch"
    else echo "unknown"; fi
}
DISTRO=$(check_distro)

# 3. Wrapper de Terminal y Auto-instalación de Zenity
# Si no hay terminal o falta Zenity, forzamos la apertura de una terminal.
if [ -z "$TERM" ] || ! command -v zenity >/dev/null 2>&1; then
    # Si estamos aquí, es porque se hizo doble click o falta la herramienta GUI
    for term in gnome-terminal konsole xfce4-terminal alacritty xterm; do
        if command -v $term >/dev/null 2>&1; then
            # Si falta zenity, lo instalamos primero en la terminal
            if ! command -v zenity >/dev/null 2>&1; then
                exec $term -e "bash -c \"
                    echo 'Instalando dependencia necesaria: zenity...';
                    case $DISTRO in
                        fedora) sudo dnf install -y zenity ;;
                        debian) sudo apt update && sudo apt install -y zenity ;;
                        arch)   sudo pacman -S --needed --noconfirm zenity ;;
                    esac;
                    bash \$0;\""
                exit 0
            else
                # Si zenity ya está pero se ejecutó por doble click, abrimos terminal para logs
                exec $term -e "bash \"$0\""
                exit 0
            fi
        fi
    done
fi

# --- A PARTIR DE AQUÍ, ZENITY ESTÁ GARANTIZADO ---

PROGRESS_FIFO="/tmp/gaming_setup_$$.fifo"
CURRENT_USER=$(logname 2>/dev/null || echo "$USER")
TOTAL_STEPS=0
CURRENT_STEP=0

cleanup() {
    echo "Finalizando procesos..."
    [ -e "$PROGRESS_FIFO" ] && rm -f "$PROGRESS_FIFO"
    exec 3>&- 2>/dev/null
    pkill -P $$ zenity 2>/dev/null
}
trap cleanup EXIT

start_progress_ui() {
    mkfifo "$PROGRESS_FIFO"
    exec 3<> "$PROGRESS_FIFO"

    zenity --progress \
        --title="Gaming Setup" \
        --text="Preparando..." \
        --percentage=0 \
        --auto-close \
        --width=450 --no-cancel <&3 &
}

update_ui() {
    local percent=$1
    local msg=$2
    echo "$percent" >&3
    echo "# $msg" >&3
    echo -e "[GUI] $percent% - $msg"
}

run_step() {
    local cmd=$1
    local desc=$2
    ((CURRENT_STEP++))
    local percent=$(( (CURRENT_STEP * 100) / TOTAL_STEPS ))
    update_ui "$percent" "$desc"

    # Ejecución con pkexec para mantener el flujo gráfico de contraseñas
    if [[ "$cmd" == *"dnf"* || "$cmd" == *"apt"* || "$cmd" == *"pacman"* || "$cmd" == *"usermod"* || "$cmd" == *"sed"* ]]; then
        pkexec bash -c "$cmd"
    else
        bash -c "$cmd"
    fi
}

# --- INTERFAZ PRINCIPAL ---

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
                fedora) run_step "dnf install -y wine winetricks glibc.i686" "Instalando Wine y base 32-bit" ;;
                debian) run_step "dpkg --add-architecture i386 && apt update && apt install -y wine winetricks" "Instalando Wine y base 32-bit" ;;
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
                fedora) run_step "dnf install -y mesa-vulkan-drivers vulkan-loader gamemode mangohud" "Drivers y Optimización" ;;
                debian) run_step "apt install -y mesa-vulkan-drivers gamemode mangohud" "Drivers y Optimización" ;;
                arch)   run_step "pacman -S --needed --noconfirm vulkan-icd-loader lib32-vulkan-icd-loader gamemode mangohud" "Drivers y Optimización" ;;
            esac ;;
        "STEAM")
            case "$DISTRO" in
                fedora) run_step "dnf install -y steam discord" "Instalando Steam y Discord" ;;
                debian) run_step "apt install -y steam" "Instalando Steam" ;;
                arch)   run_step "pacman -S --needed --noconfirm steam discord" "Instalando Steam y Discord" ;;
            esac ;;
        "CODECS")
            case "$DISTRO" in
                fedora) run_step "dnf group upgrade --with-optional Multimedia -y && dnf install -y gstreamer1-libav ffmpeg" "Codecs Multimedia" ;;
                debian) run_step "apt install -y gstreamer1.0-plugins-bad gstreamer1.0-libav ffmpeg" "Codecs Multimedia" ;;
                arch)   run_step "pacman -S --needed --noconfirm ffmpeg gstreamer gst-libav" "Codecs Multimedia" ;;
            esac ;;
    esac
done

update_ui 100 "¡Todo listo!"
sleep 2
zenity --info --title="Completado" --text="Configuración finalizada.\nSe recomienda reiniciar para aplicar cambios de drivers." --width=300

exit 0
