#!/bin/bash

# Gaming Setup Script con Interfaz Gráfica Adaptable
# Soporta Fedora, Debian/Ubuntu, Arch/Manjaro
# Incluye codecs multimedia y fallback si no hay zenity

# Verificar si estamos en modo gráfico sin terminal
if [ -n "$DISPLAY" ] && [ -z "$TERM" ]; then
    # Intentar abrir en terminal
    if command -v gnome-terminal &>/dev/null; then
        exec gnome-terminal -- bash -c "bash \"$0\"; echo 'Presiona Enter para salir...'; read"
    elif command -v konsole &>/dev/null; then
        exec konsole -e bash -c "bash \"$0\"; read -p 'Presiona Enter para salir...'"
    elif command -v xterm &>/dev/null; then
        exec xterm -e bash -c "bash \"$0\"; echo 'Presiona Enter para salir...'; read"
    elif command -v x-terminal-emulator &>/dev/null; then
        exec x-terminal-emulator -e "bash \"$0\""
    else
        echo "No se encontró una terminal. Ejecuta desde terminal o instala una."
        exit 1
    fi
    exit 0
fi

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

# Función para ejecutar comandos con privilegios
run_with_privileges() {
    local cmd="$1"
    local desc="$2"
    
    echo -e "${YELLOW}${desc}...${NC}"
    
    if command -v pkexec &>/dev/null; then
        pkexec bash -c "$cmd"
    else
        sudo bash -c "$cmd"
    fi
}

# Función para instalar zenity automáticamente
install_zenity() {
    echo -e "${YELLOW}Instalando zenity...${NC}"
    case "$DISTRO" in
        fedora)
            run_with_privileges "dnf install -y zenity" "Instalando zenity"
            ;;
        debian)
            run_with_privileges "apt update && apt install -y zenity" "Actualizando repositorios e instalando zenity"
            ;;
        arch)
            run_with_privileges "pacman -S --needed --noconfirm zenity" "Instalando zenity"
            ;;
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

# Obtener el usuario actual (antes de elevar privilegios)
CURRENT_USER=$(who | awk '{print $1}' | head -1)
if [[ -z "$CURRENT_USER" ]]; then
    CURRENT_USER=$(logname 2>/dev/null || echo "$USER")
fi

# Bienvenida
show_info "<b>¡Bienvenido al instalador gaming para Linux!</b>\n\nEste script prepara tu sistema para jugar con <b>Steam</b> y <b>Lutris</b>, e incluye codecs multimedia para reproducir MP4, MP3, etc.\n\nDistribución detectada: <b>$DISTRO</b>\n\nUsuario: <b>$CURRENT_USER</b>\n\n<i>Se solicitarán privilegios de administrador cuando sea necesario.</i>"

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
            run_with_privileges "dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-\$(rpm -E %fedora).noarch.rpm" "Instalando RPM Fusion Free"
            run_with_privileges "dnf install -y https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-\$(rpm -E %fedora).noarch.rpm" "Instalando RPM Fusion Nonfree"
            run_with_privileges "flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo" "Agregando repositorio Flatpak"
            ;;
        debian)
            run_with_privileges "sed -i 's/main\$/main contrib non-free non-free-firmware/' /etc/apt/sources.list" "Habilitando repositorios contrib y non-free"
            run_with_privileges "apt update" "Actualizando repositorios"
            ;;
        arch)
            if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
                run_with_privileges "echo -e '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf" "Habilitando multilib"
                run_with_privileges "pacman -Sy" "Sincronizando repositorios"
            fi
            ;;
    esac
}

install_wine() {
    show_info "Instalando Wine y Winetricks..."
    case "$DISTRO" in
        fedora) 
            run_with_privileges "dnf install -y wine winetricks" "Instalando Wine y Winetricks"
            ;;
        debian)
            run_with_privileges "apt install -y --install-recommends winehq-stable winetricks" "Instalando Wine y Winetricks"
            ;;
        arch)
            run_with_privileges "pacman -S --needed wine wine-gecko wine-mono winetricks" "Instalando Wine y Winetricks"
            ;;
    esac
}

install_lutris() {
    show_info "Instalando Lutris..."
    case "$DISTRO" in
        fedora)
            run_with_privileges "dnf install -y lutris" "Instalando Lutris"
            ;;
        debian)
            run_with_privileges "apt install -y lutris" "Instalando Lutris"
            ;;
        arch)
            run_with_privileges "pacman -S --needed lutris" "Instalando Lutris"
            ;;
    esac
}

install_graphics_libraries() {
    show_info "Instalando drivers gráficos y herramientas gaming..."
    case "$DISTRO" in
        fedora)
            run_with_privileges "dnf install -y mesa-vulkan-drivers vulkan-loader vulkan-tools gamemode mangohud dxvk steam-devices" "Instalando drivers y herramientas gaming"
            ;;
        debian)
            run_with_privileges "dpkg --add-architecture i386" "Agregando arquitectura i386"
            run_with_privileges "apt update" "Actualizando repositorios"
            run_with_privileges "apt install -y mesa-vulkan-drivers vulkan-tools gamemode mangohud" "Instalando drivers y herramientas gaming"
            ;;
        arch)
            run_with_privileges "pacman -S --needed lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader gamemode lib32-gamemode mangohud lib32-mangohud" "Instalando drivers y herramientas gaming"
            ;;
    esac
}

install_wine_dependencies() {
    show_info "Instalando bibliotecas 32-bit esenciales..."
    case "$DISTRO" in
        fedora)
            run_with_privileges "dnf install -y glibc.i686 libstdc++.i686 alsa-lib.i686 pulseaudio-libs.i686 cabextract" "Instalando bibliotecas 32-bit"
            ;;
        debian)
            run_with_privileges "apt install -y libc6:i386 libstdc++6:i386 cabextract" "Instalando bibliotecas 32-bit"
            ;;
        arch)
            run_with_privileges "pacman -S --needed lib32-glibc lib32-gcc-libs lib32-alsa-lib cabextract" "Instalando bibliotecas 32-bit"
            ;;
    esac
}

install_gaming_tools() {
    show_info "Instalando Steam y herramientas adicionales..."
    case "$DISTRO" in
        fedora)
            run_with_privileges "dnf install -y steam discord" "Instalando Steam y Discord"
            run_with_privileges "flatpak install -y flathub com.heroicgameslauncher.hgl net.davidotek.pupgui2" "Instalando Heroic Games Launcher y ProtonUp-Qt"
            ;;
        debian)
            run_with_privileges "apt install -y steam" "Instalando Steam"
            ;;
        arch)
            run_with_privileges "pacman -S --needed steam discord" "Instalando Steam y Discord"
            ;;
    esac
}

configure_system_optimizations() {
    show_info "Aplicando optimizaciones del sistema..."
    run_with_privileges "groupadd -r gamemode 2>/dev/null || true" "Creando grupo gamemode"
    run_with_privileges "usermod -aG gamemode $CURRENT_USER" "Agregando usuario al grupo gamemode"
    echo -e "${GREEN}Usuario $CURRENT_USER agregado al grupo gamemode.${NC}"
}

install_multimedia_codecs() {
    show_info "Instalando codecs multimedia (MP4, MP3, MKV, etc.)..."
    case "$DISTRO" in
        fedora)
            run_with_privileges "dnf swap ffmpeg-free ffmpeg --allowerasing -y" "Reemplazando ffmpeg-free por ffmpeg"
            run_with_privileges "dnf install -y gstreamer1-plugins-bad gstreamer1-plugins-good gstreamer1-plugins-ugly gstreamer1-plugin-openh264 gstreamer1-libav ffmpeg lame-libs" "Instalando codecs multimedia"
            run_with_privileges "dnf group upgrade --with-optional Multimedia -y" "Actualizando grupo Multimedia"
            ;;
        debian)
            run_with_privileges "apt update" "Actualizando repositorios"
            if command -v ubuntu-drivers >/dev/null 2>&1; then
                run_with_privileges "apt install -y ubuntu-restricted-extras" "Instalando codecs restringidos de Ubuntu"
            else
                run_with_privileges "apt install -y gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav ffmpeg" "Instalando codecs multimedia"
            fi
            ;;
        arch)
            run_with_privileges "pacman -S --needed ffmpeg gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav" "Instalando codecs multimedia"
            ;;
    esac
}

configure_wine_with_winetricks() {
    if [[ $(show_question "<b>Configuración avanzada de Wine</b>\nEsto instalará VCRedist, .NET, DirectX y fuentes.\nPuede tardar mucho tiempo. ¿Continuar?") == "no" ]]; then
        return
    fi
    show_info "Configurando Wine con winetricks (esto puede tardar...)"
    
    # Verificar si winetricks está instalado
    if ! command -v winetricks >/dev/null 2>&1; then
        echo -e "${RED}Winetricks no está instalado. Instalándolo primero...${NC}"
        case "$DISTRO" in
            fedora) run_with_privileges "dnf install -y winetricks" "Instalando Winetricks" ;;
            debian) run_with_privileges "apt install -y winetricks" "Instalando Winetricks" ;;
            arch) run_with_privileges "pacman -S --needed winetricks" "Instalando Winetricks" ;;
        esac
    fi
    
    # Configurar Wine como usuario normal
    echo -e "${YELLOW}Configurando Wine para el usuario $CURRENT_USER...${NC}"
    su -c "export WINEPREFIX=\"\$HOME/.wine\" && winetricks -q vcrun2019 dotnet48 corefonts d3dx9" "$CURRENT_USER"
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