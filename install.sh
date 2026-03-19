#!/bin/bash
# ============================================================
#  SnowFoxOS v2.0 — Installer
#  Basis: Debian 12 (Bookworm) minimal
#  Desktop: Sway + Waybar + Wofi + Dunst + Swaylock
#  Ausführen: sudo ./install.sh
# ============================================================

set -e

PURPLE='\033[0;35m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
GRAY='\033[0;37m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${PURPLE}${BOLD}[SnowFox]${RESET} $1"; }
success() { echo -e "${GREEN}${BOLD}[  OK  ]${RESET} $1"; }
warn()    { echo -e "${ORANGE}${BOLD}[ WARN ]${RESET} $1"; }
error()   { echo -e "${RED}${BOLD}[FEHLER]${RESET} $1"; exit 1; }
step()    { echo -e "\n${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}";
            echo -e "${PURPLE}${BOLD}  $1${RESET}";
            echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"; }

# Root-Check
if [[ $EUID -ne 0 ]]; then
    error "Bitte mit sudo ausführen: sudo ./install.sh"
fi

# Ziel-User ermitteln
TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
    read -rp "Benutzername: " TARGET_USER
fi
TARGET_HOME="/home/$TARGET_USER"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ ! -d "$TARGET_HOME" ]] && error "Home $TARGET_HOME nicht gefunden"

info "Installiere für: ${BOLD}$TARGET_USER${RESET}"
sleep 1

# ============================================================
# SCHRITT 1 — System aktualisieren
# ============================================================
step "1/8 — System aktualisieren"

apt-get update -qq
apt-get upgrade -y
apt-get install -y \
    curl wget git unzip \
    build-essential \
    ca-certificates \
    pciutils usbutils \
    htop btop neofetch \
    bash-completion \
    xdg-utils \
    xdg-user-dirs \
    rfkill

# Standard-Ordner erstellen (Bilder, Musik, etc.)
sudo -u "$TARGET_USER" xdg-user-dirs-update

success "System aktualisiert"

# ============================================================
# SCHRITT 2 — GPU-Erkennung & Treiber
# ============================================================
step "2/8 — GPU-Erkennung & Treiber"

GPU_INFO=$(lspci | grep -iE 'vga|3d|display')
HAS_NVIDIA=false
HAS_AMD=false
IS_HYBRID=false

echo "$GPU_INFO" | grep -qi "nvidia" && HAS_NVIDIA=true && info "Nvidia GPU gefunden"
echo "$GPU_INFO" | grep -qi "amd\|radeon\|advanced micro" && HAS_AMD=true && info "AMD GPU gefunden"
$HAS_NVIDIA && $HAS_AMD && IS_HYBRID=true && warn "Hybrid-GPU (AMD + Nvidia) — envycontrol wird installiert"

# AMD
if $HAS_AMD; then
    apt-get install -y firmware-amd-graphics libgl1-mesa-dri mesa-vulkan-drivers
    success "AMD Treiber installiert"
fi

# Nvidia
if $HAS_NVIDIA; then
    grep -q "non-free" /etc/apt/sources.list || \
        sed -i 's/main$/main contrib non-free non-free-firmware/' /etc/apt/sources.list
    apt-get update -qq
    apt-get install -y nvidia-driver firmware-misc-nonfree
    apt-get install -y libgbm1 libnvidia-egl-wayland1 2>/dev/null || true
    success "Nvidia Treiber installiert"
fi

# Hybrid
if $IS_HYBRID; then
    apt-get install -y python3 python3-pip
    pip3 install envycontrol --break-system-packages 2>/dev/null || pip3 install envycontrol
    success "envycontrol installiert (sudo envycontrol -s hybrid|nvidia|integrated)"
fi

# Fallback
if ! $HAS_NVIDIA && ! $HAS_AMD; then
    apt-get install -y libgl1-mesa-dri mesa-vulkan-drivers 2>/dev/null || true
fi

# ============================================================
# SCHRITT 3 — Sway & Wayland Desktop
# ============================================================
step "3/8 — Sway + Waybar + Wofi + Dunst + Swaylock"

apt-get install -y \
    sway \
    swaybg \
    swayidle \
    swaylock \
    waybar \
    wofi \
    dunst \
    libnotify-bin \
    xwayland \
    wl-clipboard \
    grim \
    slurp \
    brightnessctl \
    playerctl \
    network-manager \
    network-manager-gnome \

    blueman \
    bluez \
    fonts-inter \
    fonts-noto \
    fonts-noto-color-emoji \
    papirus-icon-theme

success "Sway Desktop installiert"

# Sway startet automatisch nach Login in TTY1
BASH_PROFILE="$TARGET_HOME/.bash_profile"
if ! grep -q "exec sway" "$BASH_PROFILE" 2>/dev/null; then
    echo '' >> "$BASH_PROFILE"
    echo '# SnowFoxOS — Sway automatisch starten' >> "$BASH_PROFILE"
    echo '[ "$(tty)" = "/dev/tty1" ] && exec sway' >> "$BASH_PROFILE"
fi

# Kein Autologin — Benutzer gibt Passwort ein
rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf
rmdir /etc/systemd/system/getty@tty1.service.d 2>/dev/null || true

# Andere Display Manager deaktivieren
systemctl disable lightdm 2>/dev/null || true
systemctl disable greetd  2>/dev/null || true
systemctl disable gdm3    2>/dev/null || true

success "Sway Autostart eingerichtet (Login → Passwort → Sway startet)"

# ============================================================
# SCHRITT 4 — Audio (PipeWire)
# ============================================================
step "4/8 — Audio (PipeWire)"

apt-get install -y \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    wireplumber \
    pavucontrol

# PulseAudio entfernen falls vorhanden
apt-get remove --purge -y pulseaudio pulseaudio-utils 2>/dev/null || true

# PipeWire für den User aktivieren
sudo -u "$TARGET_USER" systemctl --user enable pipewire pipewire-pulse wireplumber 2>/dev/null || true

success "PipeWire installiert"

# ============================================================
# SCHRITT 5 — Terminal & Apps
# ============================================================
step "5/8 — Terminal & Standard-Apps"

apt-get install -y \
    kitty \
    firefox-esr \
    thunar \
    thunar-archive-plugin \
    thunar-volman \
    gvfs \
    gvfs-backends \
    mousepad \
    ristretto \
    file-roller

success "Terminal (Kitty) & Apps installiert"

# ============================================================
# SCHRITT 6 — Wine
# ============================================================
step "6/8 — Wine (.exe Kompatibilität)"

dpkg --add-architecture i386
apt-get update -qq
apt-get install -y wine wine32 wine64 2>/dev/null || \
    apt-get install -y wine 2>/dev/null || \
    warn "Wine nicht installierbar — manuell: apt install wine"

cat > /usr/share/applications/wine-open.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Mit Wine öffnen
Exec=wine %f
MimeType=application/x-ms-dos-executable;application/x-msi;
NoDisplay=false
Icon=wine
EOF

success "Wine installiert"

# ============================================================
# SCHRITT 7 — zram & Optimierung
# ============================================================
step "7/8 — zram & Optimierung"

apt-get install -y zram-tools

cat > /etc/default/zramswap << 'EOF'
ALGO=lz4
PERCENT=50
PRIORITY=100
EOF

systemctl enable zramswap

# Unnötige Dienste deaktivieren
info "Unnötige Dienste deaktivieren..."
for svc in avahi-daemon cups cups-browsed ModemManager e2scrub_reap; do
    systemctl disable "$svc" 2>/dev/null && info "  Deaktiviert: $svc" || true
done
systemctl mask NetworkManager-wait-online.service 2>/dev/null || true

# NetworkManager WLAN-Fix
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/snowfox.conf << 'EOF'
[device]
wifi.scan-rand-mac-address=no

[main]
plugins=ifupdown,keyfile

[ifupdown]
managed=true
EOF

systemctl enable NetworkManager

success "zram + Optimierungen fertig"

# ============================================================
# SCHRITT 8 — Konfigurationsdateien & Darkmode
# ============================================================
step "8/8 — Konfiguration & Darkmode"

CONFIG_DIR="$TARGET_HOME/.config"
mkdir -p \
    "$CONFIG_DIR/sway" \
    "$CONFIG_DIR/waybar" \
    "$CONFIG_DIR/wofi" \
    "$CONFIG_DIR/dunst" \
    "$CONFIG_DIR/swaylock" \
    "$CONFIG_DIR/kitty" \
    "$CONFIG_DIR/gtk-3.0" \
    "$CONFIG_DIR/gtk-4.0" \
    "$TARGET_HOME/Pictures/wallpapers"

# Sway
cp "$SCRIPT_DIR/configs/sway/config"       "$CONFIG_DIR/sway/config"
cp "$SCRIPT_DIR/configs/sway/wallpaper.sh" "$CONFIG_DIR/sway/wallpaper.sh"
cp "$SCRIPT_DIR/configs/sway/powermenu.sh" "$CONFIG_DIR/sway/powermenu.sh"
chmod +x "$CONFIG_DIR/sway/wallpaper.sh"
chmod +x "$CONFIG_DIR/sway/powermenu.sh"

# Waybar
cp "$SCRIPT_DIR/configs/waybar/config"    "$CONFIG_DIR/waybar/config"
cp "$SCRIPT_DIR/configs/waybar/style.css" "$CONFIG_DIR/waybar/style.css"

# Wofi
cp "$SCRIPT_DIR/configs/wofi/config"    "$CONFIG_DIR/wofi/config"
cp "$SCRIPT_DIR/configs/wofi/style.css" "$CONFIG_DIR/wofi/style.css"

# Dunst
cp "$SCRIPT_DIR/configs/dunst/dunstrc" "$CONFIG_DIR/dunst/dunstrc"

# Swaylock
cp "$SCRIPT_DIR/configs/swaylock/config" "$CONFIG_DIR/swaylock/config"

# Kitty Terminal
cat > "$CONFIG_DIR/kitty/kitty.conf" << 'EOF'
# SnowFoxOS — Kitty Terminal
font_family       Noto Mono
font_size         11.0
cursor            #9B59B6
cursor_text_color #0f0f0f
background        #0f0f0f
foreground        #e8e8e8
color0   #1a1a1a
color1   #e05555
color2   #5faf5f
color3   #E67E22
color4   #5f87af
color5   #9B59B6
color6   #5fafaf
color7   #bcbcbc
color8   #3a3a3a
color9   #ff6e6e
color10  #87d787
color11  #ffd787
color12  #87afd7
color13  #c397d8
color14  #87d7d7
color15  #e8e8e8
window_padding_width 8
hide_window_decorations yes
confirm_os_window_close 0
EOF

# GTK3 Darkmode
cat > "$CONFIG_DIR/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Noto Sans 10
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
EOF

# GTK4 Darkmode
cat > "$CONFIG_DIR/gtk-4.0/settings.ini" << 'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
EOF

success "GTK Darkmode gesetzt (Firefox, Thunar, alle GTK-Apps)"

# Wayland + Qt Umgebungsvariablen
# QT_QPA_PLATFORM=wayland;xcb = versuche Wayland, Fallback auf XCB (fuer MegaSync etc.)
cat > /etc/environment << 'EOF'
MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM=wayland;xcb
QT_QPA_PLATFORMTHEME=gtk3
GDK_BACKEND=wayland,x11
XDG_CURRENT_DESKTOP=sway
XDG_SESSION_TYPE=wayland
CLUTTER_BACKEND=wayland
EOF

success "Wayland/Qt Umgebungsvariablen gesetzt (inkl. MegaSync-Fix)"

# Wallpaper kopieren
if ls "$SCRIPT_DIR/wallpapers"/*.{jpg,png,jpeg} &>/dev/null 2>&1; then
    cp "$SCRIPT_DIR/wallpapers"/* "$TARGET_HOME/Pictures/wallpapers/" 2>/dev/null || true
    success "Wallpapers kopiert"
fi

# snowfox-lite Script
cat > /usr/local/bin/snowfox-lite << 'EOF'
#!/bin/bash
# SnowFoxOS Leicht-Modus fuer alte Hardware
case "$1" in
    on)
        echo "export WLR_NO_HARDWARE_CURSORS=1" >> ~/.bash_profile
        echo "Leicht-Modus aktiv — beim naechsten Login wirksam"
        ;;
    off)
        sed -i '/WLR_NO_HARDWARE_CURSORS/d' ~/.bash_profile
        echo "Leicht-Modus deaktiviert"
        ;;
    *) echo "Verwendung: snowfox-lite [on|off]" ;;
esac
EOF
chmod +x /usr/local/bin/snowfox-lite

# Berechtigungen setzen
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/Pictures"

# ============================================================
# Fertig!
# ============================================================
echo ""
echo -e "${PURPLE}${BOLD}"
echo "  ███████╗███╗  ██╗ ██████╗ ██╗    ██╗███████╗ ██████╗ ██╗  ██╗"
echo "  ██╔════╝████╗ ██║██╔═══██╗██║    ██║██╔════╝██╔═══██╗╚██╗██╔╝"
echo "  ███████╗██╔██╗██║██║   ██║██║ █╗ ██║█████╗  ██║   ██║ ╚███╔╝ "
echo "  ╚════██║██║╚████║██║   ██║██║███╗██║██╔══╝  ██║   ██║ ██╔██╗ "
echo "  ███████║██║ ╚███║╚██████╔╝╚███╔███╔╝██║     ╚██████╔╝██╔╝╚██╗"
echo "  ╚══════╝╚═╝  ╚══╝ ╚═════╝  ╚══╝╚══╝ ╚═╝      ╚═════╝ ╚═╝  ╚═╝"
echo -e "${RESET}"
echo -e "${GREEN}${BOLD}  SnowFoxOS v2.0 erfolgreich installiert!${RESET}"
echo ""
echo -e "${GRAY}  Benutzer:   ${BOLD}$TARGET_USER${RESET}"
echo -e "${GRAY}  Desktop:    ${BOLD}Sway + Waybar${RESET}"
echo -e "${GRAY}  Audio:      ${BOLD}PipeWire${RESET}"
echo -e "${GRAY}  Darkmode:   ${BOLD}GTK3 + GTK4${RESET}"
echo -e "${GRAY}  GPU:        ${BOLD}$(
    $IS_HYBRID && echo "Hybrid (AMD + Nvidia)" || \
    { $HAS_NVIDIA && echo "Nvidia"; } || \
    { $HAS_AMD && echo "AMD"; } || \
    echo "Intel/andere"
)${RESET}"
echo -e "${GRAY}  zram:       ${BOLD}aktiv (lz4, 50%)${RESET}"
echo -e "${GRAY}  Login:      ${BOLD}TTY1 → Passwort → Sway${RESET}"
echo ""
echo -e "${ORANGE}${BOLD}  Shortcuts:${RESET}"
echo -e "  ${GRAY}Super+Return   ${RESET}Terminal"
echo -e "  ${GRAY}Super+Space    ${RESET}App-Launcher"
echo -e "  ${GRAY}Super+B        ${RESET}Firefox"
echo -e "  ${GRAY}Super+E        ${RESET}Dateimanager"
echo -e "  ${GRAY}Super+L        ${RESET}Bildschirm sperren"
echo -e "  ${GRAY}Super+Shift+E  ${RESET}Power-Menü"
echo ""
echo -e "${ORANGE}${BOLD}  → Neu starten: sudo reboot${RESET}"
echo ""
