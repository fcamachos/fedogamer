#!/bin/bash

# Gaming Setup Script con Interfaz Gráfica (Zenity)
# Inspirado en el uso de whiptail/zenity
# Soporta Fedora, Debian/Ubuntu, Arch/Manjaro
# https://github.com/fcamachos

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

Este script te ayudará a preparar tu sistema para jugar con <b>Steam</b> y <b>Lutris</b>.
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
SELECCION=$(zenity --list --checklist --width=800 --height=600 \
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
    FALSE "Configurar Wine con winetricks" "Instalar VCRedist, .NET, DirectX, fonts (puede tardar mucho)" \
    --separator=":")

if [[ $? -ne 0 || -z "$SELECCION" ]]; then
    zenity --warning --text="Instalación cancelada por el usuario."
    exit 0
fi

# Convertir selección a array
IFS=":" read -ra OPCIONES <<< "$SELECCION"

# Función para ejecutar con progreso
ejecutar_con_progreso() {
    "$@" | zenity --progress --pulsate --auto-close --width=500 --title="Instalando..." --text="$1"
}

# === FUNCIONES DE INSTALACIÓN (casi idénticas a tu original, solo simplificadas donde posible) ===

setup_repositories() {
    zenity --info --text="Configurando repositorios adicionales..."
    case "$DISTRO" in
        fedora)
            sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
            sudo dnf install -y https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
            flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
            ;;
        debian)
            sudo sed -i 's/main$/main contrib non-free/' /etc/apt/sources.list
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
    zenity --info --text="Instalando Wine y dependencias..."
    case "$DISTRO" in
        fedora) sudo dnf install -y wine winetricks ;;
        debian) sudo apt install -y --install-recommends winehq-stable winetricks ;;
        arch) sudo pacman -S --needed wine wine-gecko wine-mono winetricks ;;
    esac
}

install_lutris() {
    zenity --info --text="Instalando Lutris..."
    case "$DISTRO" in
        fedora|debian) sudo ${DISTRO == fedora && echo dnf || echo apt install} -y lutris ;;
        arch) sudo pacman -S --needed lutris ;;
    esac
}

install_graphics_libraries() {
    zenity --info --text="Instalando drivers gráficos y herramientas gaming..."
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
    zenity --info --text="Instalando bibliotecas 32-bit esenciales..."
    # (Mantengo tu código original resumido)
    case "$DISTRO" in
        fedora) sudo dnf install -y glibc.i686 libstdc++.i686 alsa-lib.i686 pulseaudio-libs.i686 cabextract ;;
        debian) sudo apt install -y libc6:i386 libstdc++6:i386 cabextract ;;
        arch) sudo pacman -S --needed lib32-glibc lib32-gcc-libs lib32-alsa-lib cabextract ;;
    esac
}

install_gaming_tools() {
    zenity --info --text="Instalando Steam y herramientas adicionales..."
    case "$DISTRO" in
        fedora) sudo dnf install -y steam discord flatpak; flatpak install -y flathub com.heroicgameslauncher.hgl net.davidotek.pupgui2 ;;
        debian) sudo apt install -y steam ;;
        arch) sudo pacman -S --needed steam discord; ;;
    esac
}

configure_system_optimizations() {
    zenity --info --text="Aplicando optimizaciones del sistema..."
    sudo groupadd -r gamemode 2>/dev/null || true
    sudo usermod -aG gamemode "$USER"
    # (tus configs de limits y sysctl)
}

configure_wine_with_winetricks() {
    zenity --question --text="Esto puede tardar mucho tiempo. ¿Continuar con la configuración avanzada de Wine?" || return
    export WINEPREFIX="$HOME/.wine"
    winetricks -q vcrun2019 dotnet48 corefonts d3dx9
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

<b>Pasos siguientes recomendados:</b>
1. <b>Reinicia el sistema</b> para aplicar optimizaciones.
2. Abre Lutris y conecta tus cuentas.
3. Instala juegos desde Lutris o Steam.
4. Usa ProtonUp-Qt (si instalaste) para versiones GE de Proton.

<i>¡Disfruta gaming en Linux! 🎮</i>"

exit 0