#!/bin/bash

# Gaming Setup Script con Interfaz Gráfica (Zenity)
# Inspirado en el uso de whiptail/zenity
# Soporta Fedora, Debian/Ubuntu, Arch/Manjaro

# Colores (para terminal)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Verificar si zenity está instalado
if ! command -v zenity >/dev/null 2>&1; then
    echo -e "${YELLOW}Instalando zenity (necesario para la GUI)...${NC}"
    if [[ -f /etc/fedora-release ]]; then
        sudo dnf install -y zenity
    elif [[ -f /etc/debian_version ]]; then
        sudo apt install -y zenity
    elif [[ -f /etc/arch-release ]]; then
        sudo pacman -S --needed zenity
    else
        echo -e "${RED}Distribución no soportada para instalación automática de zenity.${NC}"
        exit 1
    fi
fi

# Banner inicial
zenity --info --width=500 --title="FedoGamer Setup" --text="
<b>¡Bienvenido al instalador gaming para Linux!</b>

Este script te ayudará a preparar tu sistema para jugar con <b>Steam</b> y <b>Lutris</b>, 
y ahora también incluye codecs multimedia para reproducir MP4 y otros formatos.

Se detectará automáticamente tu distribución.

<i>Requiere privilegios sudo y conexión a internet.</i>"

# Detectar distribución
check_distro() {
    if [[ -f /etc/fedora-release ]]; then echo "fedora"
    elif [[ -f /etc/debian_version ]]; then echo "debian"
    elif [[ -f /etc/arch-release ]]; then echo "arch"
    else echo "unknown"; fi
}

DISTRO=$(check_distro)

if [[ "$DISTRO" == "unknown" ]]; then
    zenity --error --text="Distribución no soportada (solo Fedora, Debian/Ubuntu y Arch)."
    exit 1
fi

zenity --info --text="Distribución detectada: <b>$DISTRO</b>"

# Checklist de opciones
SELECCION=$(zenity --list --checklist --width=800 --height=650 \
    --title="Selecciona lo que quieres instalar/configurar" \
    --text="Marca las opciones deseadas (puedes elegir varias):" \
    --column="Seleccionar" --column="Opción" --column="Descripción" \
    TRUE "Repositorios" "Configurar repos adicionales (RPM Fusion, contrib/non-free, multilib)" \
    TRUE "Wine" "Instalar Wine + Winetricks + dependencias básicas" \
    TRUE "Lutris" "Instalar Lutris" \
    TRUE "Drivers gráficos" "Drivers Vulkan, Mesa, DXVK, GameMode, MangoHud, etc." \
    TRUE "Dependencias 32-bit" "Bibliotecas esenciales para juegos Windows" \
    TRUE "Steam y herramientas" "Instalar Steam + herramientas gaming (Heroic, ProtonUp-Qt, etc.)" \
    TRUE "Optimizaciones sistema" "GameMode, límites de recursos y parámetros kernel" \
    TRUE "Codecs multimedia" "Instalar codecs para MP4, MP3, AVI, MKV, etc. (GStreamer + FFmpeg)" \
    FALSE "Configurar Wine con winetricks" "Instalar VCRedist, .NET, DirectX, fonts (puede tardar mucho)" \
    --separator=":")

if [[ $? -ne 0 || -z "$SELECCION" ]]; then
    zenity --warning --text="Instalación cancelada por el usuario."
    exit 0
fi

# Convertir selección a array
IFS=":" read -ra OPCIONES <<< "$SELECCION"

# === NUEVA FUNCIÓN PARA CODECS MULTIMEDIA ===
install_multimedia_codecs() {
    zenity --info --text="Instalando codecs multimedia (MP4/H.264, MP3, etc.)..."
    case "$DISTRO" in
        fedora)
            # Comandos recomendados por RPM Fusion para codecs completos
            sudo dnf swap ffmpeg-free ffmpeg --allowerasing -y
            sudo dnf install -y gstreamer1-plugins-{bad-\*,good-\*,base,ugly-\*} gstreamer1-plugin-openh264 gstreamer1-libav ffmpeg lame-libs --exclude=gstreamer1-plugins-bad-free-devel
            sudo dnf group upgrade --with-optional Multimedia -y
            ;;
        debian)
            sudo apt update
            # Para Ubuntu: ubuntu-restricted-extras incluye la mayoría
            # Para Debian puro: paquetes equivalentes
            if command -v ubuntu-drivers >/dev/null 2>&1; then
                sudo apt install -y ubuntu-restricted-extras
            else
                sudo apt install -y gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav ffmpeg
            fi
            sudo apt install -y libavcodec-extra libdvd-pkg
            sudo dpkg-reconfigure libdvd-pkg
            ;;
        arch)
            sudo pacman -S --needed ffmpeg gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav
            ;;
    esac
}

setup_repositories() {
    zenity --info --text="Configurando repositorios adicionales..."
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

# === EJECUCIÓN DE OPCIONES SELECCIONADAS ===
for opcion in "${OPCIONES[@]}"; do
    case "$opcion" in
        Repositorios) setup_repositories ;;
        Wine) install_wine ;;
        Lutris) install_lutris ;;
        "Drivers gráficos") install_graphics_libraries ;;
        "Dependencias 32-bit") install_wine_dependencies ;;
        "Steam y herramientas") install_gaming_tools ;;
        "Optimizaciones sistema") configure_system_optimizations ;;
        "Codecs multimedia") install_multimedia_codecs ;;
        "Configurar Wine con winetricks") configure_wine_with_winetricks ;;
    esac
done

# Mensaje final
zenity --info --width=600 --title="¡Instalación completada!" --text="
<b>¡Todo listo!</b>

Software principal instalado:
✓ Wine / Lutris / Steam
✓ Drivers Vulkan y herramientas gaming
✓ Bibliotecas compatibilidad
✓ <b>Codecs multimedia (MP4, MP3, etc.)</b>

<b>Pasos siguientes recomendados:</b>
1. <b>Reinicia el sistema</b> para aplicar los cambios.
2. Abre Lutris y conecta tus cuentas.
3. Prueba reproducir un vídeo MP4 con tu reproductor favorito (Totem, VLC, etc.).
4. Usa ProtonUp-Qt (si instalaste) para versiones GE de Proton.

<i>¡Disfruta gaming y multimedia en Linux! 🎮🎥</i>"

exit 0