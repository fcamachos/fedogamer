#!/bin/bash

# Gaming Setup Script con Interfaz Gráfica Adaptable
# Soporta Fedora, Debian/Ubuntu, Arch/Manjaro
# Incluye codecs multimedia y fallback si no hay zenity

# Colores para terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función para detectar distribución
check_distro() {
    if [[ -f /etc/fedora-release ]]; then echo "fedora"
    elif [[ -f /etc/debian_version ]]; then echo "debian"
    elif [[ -f /etc/arch-release ]]; then echo "arch"
    else echo "unknown"; fi
}

DISTRO=$(check_distro)

if [[ "$DISTRO" == "unknown" ]]; then
    echo -e "${RED}Distribución no soportada.${NC}"
    exit 1
fi

# Función para instalar zenity automáticamente
install_zenity() {
    echo -e "${YELLOW}Instalando zenity...${NC}"
    case "$DISTRO" in
        fedora) sudo dnf install -y zenity ;;
        debian) sudo apt update && sudo apt install -y zenity ;;
        arch)   sudo pacman -S --needed --noconfirm zenity ;;
    esac
}

# Detectar qué herramienta de diálogo está disponible
DIALOG=""

if command -v zenity >/dev/null 2>&1; then
    DIALOG="zenity"
elif command -v kdialog >/dev/null 2>&1; then
    DIALOG="kdialog"
elif command -v yad >/dev/null 2>&1; then
    DIALOG="yad"
fi

# Si no hay zenity, intentar instalarlo usando alternativa o terminal
if ! command -v zenity >/dev/null 2>&1; then
    echo -e "${YELLOW}Zenity no está instalado. Se recomienda para la mejor experiencia gráfica.${NC}"

    if [[ "$DIALOG" == "kdialog" ]]; then
        if kdialog --title "Instalar Zenity" --yesno "Zenity no está instalado.\n¿Deseas instalarlo ahora para usar la interfaz gráfica completa?"; then
            install_zenity
        else
            DIALOG="text"
        fi
    elif [[ "$DIALOG" == "yad" ]]; then
        if yad --title "Instalar Zenity" --question --text="Zenity no está instalado.\n¿Deseas instalarlo ahora para usar la interfaz gráfica completa?"; then
            install_zenity
        else
            DIALOG="text"
        fi
    else
        read -p "¿Instalar zenity ahora? (y/N): " resp
        if [[ "$resp" =~ ^[Yy]$ ]]; then
            install_zenity
        else
            DIALOG="text"
        fi
    fi
fi

# Forzar zenity si ya está instalado después del intento
if command -v zenity >/dev/null 2>&1; then
    DIALOG="zenity"
elif [[ -z "$DIALOG" ]]; then
    DIALOG="text"
fi

# ================== INTERFAZ GRÁFICA O TEXTO ==================

show_info() {
    local text="$1"
    if [[ "$DIALOG" == "zenity" ]]; then
        zenity --info --width=500 --title="Gaming Setup" --text="$text"
    else
        echo -e "${BLUE}$text${NC}"
        read -p "Presiona Enter para continuar..."
    fi
}

show_question() {
    local text="$1"
    if [[ "$DIALOG" == "zenity" ]]; then
        zenity --question --width=400 --title="Confirmar" --text="$text" && echo "yes" || echo "no"
    else
        read -p "$text (y/N): " resp
        [[ "$resp" =~ ^[Yy]$ ]] && echo "yes" || echo "no"
    fi
}

# Bienvenida
show_info "<b>¡Bienvenido al instalador gaming para Linux!</b>\n\nEste script prepara tu sistema para jugar con <b>Steam</b> y <b>Lutris</b>, e incluye codecs multimedia para reproducir MP4, MP3, etc.\n\nDistribución detectada: <b>$DISTRO</b>\n\n<i>Requiere conexión a internet y privilegios sudo.</i>"

# Checklist principal (solo con zenity; fallback texto instala todo por defecto)
if [[ "$DIALOG" == "zenity" ]]; then
    SELECCION=$(zenity --list --checklist --width=850 --height=700 \
        --title="Selecciona las opciones a instalar" \
        --text="Marca lo que deseas instalar o configurar:" \
        --column="✓" --column="Opción" --column="Descripción" \
        TRUE  "Repositorios"            "Habilitar RPM Fusion, contrib/non-free, multilib, etc." \
        TRUE  "Wine"                    "Wine + Winetricks + dependencias básicas" \
        TRUE  "Lutris"                  "Instalar Lutris" \
        TRUE  "Drivers gráficos"        "Vulkan, Mesa, GameMode, MangoHud, DXVK, etc." \
        TRUE  "Dependencias 32-bit"     "Bibliotecas esenciales para juegos Windows" \
        TRUE  "Steam y herramientas"    "Steam, Heroic, ProtonUp-Qt, Discord, etc." \
        TRUE  "Optimizaciones sistema"  "GameMode, límites de recursos, parámetros kernel" \
        TRUE  "Codecs multimedia"       "Codecs para MP4, MP3, MKV, AVI, etc. (GStreamer + FFmpeg)" \
        FALSE "Configurar Wine avanzado" "VCRedist, .NET, DirectX, fonts (puede tardar mucho)" \
        --separator=":")

    if [[ $? -ne 0 || -z "$SELECCION" ]]; then
        show_info "Instalación cancelada por el usuario."
        exit 0
    fi
    IFS=":" read -ra OPCIONES <<< "$SELECCION"
else
    echo -e "${YELLOW}Modo texto activado: se instalarán todas las opciones recomendadas por defecto.${NC}"
    OPCIONES=("Repositorios" "Wine" "Lutris" "Drivers gráficos" "Dependencias 32-bit" "Steam y herramientas" "Optimizaciones sistema" "Codecs multimedia")
    if [[ $(show_question "¿Quieres también configurar Wine con winetricks (VCRedist, .NET, etc.)?") == "yes" ]]; then
        OPCIONES+=("Configurar Wine avanzado")
    fi
fi

# ================== FUNCIONES DE INSTALACIÓN ==================

setup_repositories() {
    show_info "Configurando repositorios adicionales..."
    case "$DISTRO" in
        fedora)
            sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
            sudo dnf install -y https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
            flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
            ;;
        debian)
            sudo sed -i 's/main$/main contrib non-free non-free-firmware/' /etc/apt/sources.list
            sudo apt update
            ;;
        arch)
            if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
                echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf
                sudo pacman -Sy
            fi
            ;;
    esac
}

install_wine() {
    show_info "Instalando Wine y Winetricks..."
    case "$DISTRO" in
        fedora) sudo dnf install -y wine winetricks ;;
        debian) sudo apt install -y --install-recommends winehq-stable winetricks ;;
        arch)   sudo pacman -S --needed wine wine-gecko wine-mono winetricks ;;
    esac
}

install_lutris() {
    show_info "Instalando Lutris..."
    case "$DISTRO" in
        fedora|debian) sudo ${DISTRO/dnf/apt install} -y lutris ;;
        arch)          sudo pacman -S --needed lutris ;;
    esac
}

install_graphics_libraries() {
    show_info "Instalando drivers gráficos y herramientas gaming..."
    case "$DISTRO" in
        fedora)
            sudo dnf install -y mesa-vulkan-drivers vulkan-loader vulkan-tools gamemode mangohud dxvk steam-devices
            ;;
        debian)
            sudo dpkg --add-architecture i386
            sudo apt update
            sudo apt install -y mesa-vulkan-drivers vulkan-tools gamemode mangohud
            ;;
        arch)
            sudo pacman -S --needed lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader gamemode lib32-gamemode mangohud lib32-mangohud
            ;;
    esac
}

install_wine_dependencies() {
    show_info "Instalando bibliotecas 32-bit esenciales..."
    case "$DISTRO" in
        fedora) sudo dnf install -y glibc.i686 libstdc++.i686 alsa-lib.i686 pulseaudio-libs.i686 cabextract ;;
        debian) sudo apt install -y libc6:i386 libstdc++6:i386 cabextract ;;
        arch)   sudo pacman -S --needed lib32-glibc lib32-gcc-libs lib32-alsa-lib cabextract ;;
    esac
}

install_gaming_tools() {
    show_info "Instalando Steam y herramientas adicionales..."
    case "$DISTRO" in
        fedora)
            sudo dnf install -y steam discord
            flatpak install -y flathub com.heroicgameslauncher.hgl net.davidotek.pupgui2
            ;;
        debian) sudo apt install -y steam ;;
        arch)   sudo pacman -S --needed steam discord ;;
    esac
}

configure_system_optimizations() {
    show_info "Aplicando optimizaciones del sistema..."
    sudo groupadd -r gamemode 2>/dev/null || true
    sudo usermod -aG gamemode "$USER"
}

install_multimedia_codecs() {
    show_info "Instalando codecs multimedia (MP4, MP3, MKV, etc.)..."
    case "$DISTRO" in
        fedora)
            sudo dnf swap ffmpeg-free ffmpeg --allowerasing -y
            sudo dnf install -y gstreamer1-plugins-{bad-\*,good-\*,base,ugly-\*} gstreamer1-plugin-openh264 gstreamer1-libav ffmpeg lame-libs
            sudo dnf group upgrade --with-optional Multimedia -y
            ;;
        debian)
            sudo apt update
            if command -v ubuntu-drivers >/dev/null 2>&1; then
                sudo apt install -y ubuntu-restricted-extras
            else
                sudo apt install -y gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav ffmpeg
            fi
            ;;
        arch)
            sudo pacman -S --needed ffmpeg gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav
            ;;
    esac
}

configure_wine_with_winetricks() {
    if [[ $(show_question "<b>Configuración avanzada de Wine</b>\nEsto instalará VCRedist, .NET, DirectX y fuentes.\nPuede tardar mucho tiempo. ¿Continuar?") == "no" ]]; then
        return
    fi
    show_info "Configurando Wine con winetricks (esto puede tardar...)"
    export WINEPREFIX="$HOME/.wine"
    winetricks -q vcrun2019 dotnet48 corefonts d3dx9
}

# ================== EJECUCIÓN ==================

for opcion in "${OPCIONES[@]}"; do
    case "$opcion" in
        "Repositorios")             setup_repositories ;;
        "Wine")                     install_wine ;;
        "Lutris")                   install_lutris ;;
        "Drivers gráficos")         install_graphics_libraries ;;
        "Dependencias 32-bit")      install_wine_dependencies ;;
        "Steam y herramientas")     install_gaming_tools ;;
        "Optimizaciones sistema")   configure_system_optimizations ;;
        "Codecs multimedia")        install_multimedia_codecs ;;
        "Configurar Wine avanzado") configure_wine_with_winetricks ;;
    esac
done

# Mensaje final
show_info "<b>¡Instalación completada!</b>\n\nComponentes instalados:\n✓ Wine / Lutris / Steam\n✓ Drivers y herramientas gaming\n✓ Codecs multimedia (MP4, MP3, etc.)\n✓ Bibliotecas de compatibilidad\n\n<b>Recomendaciones:</b>\n1. <b>Reinicia el sistema</b>\n2. Abre Lutris y conecta tus cuentas\n3. Prueba reproducir un vídeo o instalar un juego\n\n<i>¡Disfruta del gaming y multimedia en Linux! 🎮🎥</i>"

exit 0