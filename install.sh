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

if [[ $EUID -ne 0 ]]; then
    error "Bitte mit sudo ausführen: sudo ./install.sh"
fi

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
    rfkill \
    imagemagick

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

if $HAS_AMD; then
    apt-get install -y firmware-amd-graphics libgl1-mesa-dri mesa-vulkan-drivers
    success "AMD Treiber installiert"
fi

if $HAS_NVIDIA; then
    grep -q "non-free" /etc/apt/sources.list || \
        sed -i 's/main$/main contrib non-free non-free-firmware/' /etc/apt/sources.list
    apt-get update -qq
    apt-get install -y nvidia-driver firmware-misc-nonfree
    apt-get install -y libgbm1 libnvidia-egl-wayland1 2>/dev/null || true
    success "Nvidia Treiber installiert"
fi

if $IS_HYBRID; then
    apt-get install -y python3 python3-pip
    pip3 install envycontrol --break-system-packages 2>/dev/null || \
        pip3 install envycontrol 2>/dev/null || \
        warn "envycontrol nicht installierbar — manuell: pip3 install envycontrol"
    if command -v envycontrol &>/dev/null; then
        envycontrol -s nvidia 2>/dev/null && \
            success "envycontrol: Nvidia-Modus aktiviert" || \
            warn "envycontrol konnte Nvidia-Modus nicht setzen — manuell: sudo envycontrol -s nvidia"
        echo ""
        warn "Hybrid-GPU erkannt: Nvidia-Modus wurde aktiviert."
        warn "Alle Monitore müssen an die Nvidia-GPU angeschlossen sein."
        warn "Monitore am Motherboard-Ausgang (iGPU) werden nicht angezeigt."
        echo ""
    fi
fi

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
    bluez \
    fonts-inter \
    fonts-noto \
    fonts-noto-color-emoji \
    papirus-icon-theme \
    wlsunset

apt-get install -y blueman 2>/dev/null || warn "Blueman nicht verfügbar — Bluetooth nur per CLI"

success "Sway Desktop installiert"

# Sway startet automatisch nach Login in TTY1
BASH_PROFILE="$TARGET_HOME/.bash_profile"
if ! grep -q "exec sway" "$BASH_PROFILE" 2>/dev/null; then
    echo '' >> "$BASH_PROFILE"
    echo '# SnowFoxOS — Sway automatisch starten' >> "$BASH_PROFILE"
    echo '[ "$(tty)" = "/dev/tty1" ] && exec sway' >> "$BASH_PROFILE"
fi

# Kein Autologin
rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf
rmdir /etc/systemd/system/getty@tty1.service.d 2>/dev/null || true
systemctl disable lightdm 2>/dev/null || true
systemctl disable greetd  2>/dev/null || true
systemctl disable gdm3    2>/dev/null || true

success "Sway Autostart eingerichtet"

# ============================================================
# SCHRITT 4 — Audio (PipeWire)
# ============================================================
step "4/8 — Audio (PipeWire)"

apt-get install -y \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    wireplumber \
    pavucontrol \
    pulseaudio-utils

apt-get remove --purge -y pulseaudio pulseaudio-utils 2>/dev/null || true
sudo -u "$TARGET_USER" systemctl --user enable pipewire pipewire-pulse wireplumber 2>/dev/null || true

success "PipeWire installiert"

# ============================================================
# SCHRITT 5 — Terminal & Apps
# ============================================================
step "5/8 — Terminal & Standard-Apps"

apt-get install -y \
    kitty \
    thunar \
    thunar-archive-plugin \
    thunar-volman \
    gvfs \
    gvfs-backends \
    mousepad \
    ristretto \
    file-roller \
    mpv \
    ffmpeg \
    gnupg

# yt-dlp direkt von GitHub — apt-Version ist immer veraltet
curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
chmod +x /usr/local/bin/yt-dlp
success "yt-dlp (neueste Version) installiert"

success "Terminal (Kitty) & Apps installiert"

# ============================================================
# SCHRITT 6 — Browser (Brave)
# ============================================================
step "6/8 — Brave Browser"

curl -fsS https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
    | tee /usr/share/keyrings/brave-browser-archive-keyring.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
    | tee /etc/apt/sources.list.d/brave-browser.list

apt-get update -qq
apt-get install -y brave-browser
apt-get remove --purge -y firefox-esr 2>/dev/null || true

BRAVE_CONFIG_DIR="$TARGET_HOME/.config/BraveSoftware/Brave-Browser/Default"
mkdir -p "$BRAVE_CONFIG_DIR"
if [[ ! -f "$BRAVE_CONFIG_DIR/Preferences" ]]; then
cat > "$BRAVE_CONFIG_DIR/Preferences" << 'EOF'
{
  "browser": {
    "has_seen_welcome_page": true,
    "show_home_button": false
  },
  "hardware_acceleration_mode": {
    "enabled": true
  },
  "background_mode": {
    "enabled": false
  },
  "performance_tuning": {
    "high_efficiency_mode": {
      "enabled": true,
      "mode": 2
    }
  },
  "profile": {
    "default_content_setting_values": {
      "notifications": 2
    }
  }
}
EOF
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config/BraveSoftware"
fi
success "Brave Browser installiert"

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

# RAM bevorzugen, spät auf zram ausweichen
cat > /etc/sysctl.d/99-snowfox.conf << 'EOF'
vm.swappiness=10
EOF

info "Unnötige Dienste deaktivieren..."
for svc in avahi-daemon cups cups-browsed ModemManager e2scrub_reap bluetooth; do
    systemctl disable "$svc" 2>/dev/null && info "  Deaktiviert: $svc" || true
done
systemctl mask NetworkManager-wait-online.service 2>/dev/null || true

# Unnötige User-Dienste maskieren — verhindert auch D-Bus Aktivierung
sudo -u "$TARGET_USER" systemctl --user mask \
    at-spi-dbus-bus.service \
    gnome-keyring-daemon.service \
    gnome-keyring-daemon.socket \
    obex.service \
    xdg-document-portal.service \
    xdg-permission-store.service 2>/dev/null || true

# Ollama nicht automatisch starten — wird on-demand durch snowfox ai gestartet
systemctl disable ollama 2>/dev/null || true

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
# SCHRITT 8 — Konfiguration, Icons & Darkmode
# ============================================================
step "8/8 — Konfiguration, Icons & Darkmode"

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
    "$CONFIG_DIR/xdg-desktop-portal" \
    "$TARGET_HOME/Pictures/wallpapers"

# Sway
cp "$SCRIPT_DIR/configs/sway/config"             "$CONFIG_DIR/sway/config"
cp "$SCRIPT_DIR/configs/sway/wallpaper.sh"       "$CONFIG_DIR/sway/wallpaper.sh"
cp "$SCRIPT_DIR/configs/sway/powermenu.sh"       "$CONFIG_DIR/sway/powermenu.sh"
cp "$SCRIPT_DIR/configs/sway/snowfox-network.sh" "$CONFIG_DIR/sway/snowfox-network.sh"
chmod +x "$CONFIG_DIR/sway/wallpaper.sh"
chmod +x "$CONFIG_DIR/sway/powermenu.sh"
chmod +x "$CONFIG_DIR/sway/snowfox-network.sh"

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

# Kitty
cat > "$CONFIG_DIR/kitty/kitty.conf" << 'EOF'
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

# mpv — Wayland Output erzwingen
mkdir -p "$CONFIG_DIR/mpv"
cat > "$CONFIG_DIR/mpv/mpv.conf" << 'EOF'
vo=gpu
gpu-context=wayland
hwdec=auto
EOF

# GTK Darkmode
cat > "$CONFIG_DIR/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Noto Sans 10
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
EOF

cat > "$CONFIG_DIR/gtk-4.0/settings.ini" << 'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
EOF

# xdg-desktop-portal-wlr (kein gtk — verhindert Timeouts)
apt-get install -y xdg-desktop-portal xdg-desktop-portal-wlr
apt-get remove --purge -y xdg-desktop-portal-gtk 2>/dev/null || true

cat > "$CONFIG_DIR/xdg-desktop-portal/portals.conf" << 'EOF'
[preferred]
default=wlr
org.freedesktop.impl.portal.Screenshot=wlr
org.freedesktop.impl.portal.ScreenCast=wlr
org.freedesktop.impl.portal.FileChooser=wlr
EOF

success "xdg-desktop-portal-wlr installiert"

# Wayland/Qt Umgebungsvariablen (via profile.d — überschreibt keine bestehenden Einträge)
cat > /etc/profile.d/snowfox-env.sh << 'EOF'
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland;xcb
export QT_QPA_PLATFORMTHEME=gtk3
export GDK_BACKEND=wayland,x11
export XDG_CURRENT_DESKTOP=sway
export XDG_SESSION_TYPE=wayland
export CLUTTER_BACKEND=wayland
EOF
chmod +x /etc/profile.d/snowfox-env.sh

# SnowFox Logo als System-Icon installieren
ASSET="$SCRIPT_DIR/assets/fuchs.png"
if [[ -f "$ASSET" ]]; then
    info "SnowFox Logo wird installiert..."
    for SIZE in 16 24 32 48 64 128 256; do
        ICON_DIR="/usr/share/icons/hicolor/${SIZE}x${SIZE}/apps"
        mkdir -p "$ICON_DIR"
        convert "$ASSET" -resize "${SIZE}x${SIZE}" "$ICON_DIR/snowfox.png" 2>/dev/null || true
    done
    gtk-update-icon-cache /usr/share/icons/hicolor/ 2>/dev/null || true
    success "SnowFox Logo als System-Icon installiert"
else
    warn "assets/fuchs.png nicht gefunden — Icon wird übersprungen"
fi

# Wallpaper kopieren
if [ -d "$SCRIPT_DIR/wallpapers" ] && [ "$(ls -A "$SCRIPT_DIR/wallpapers" 2>/dev/null)" ]; then
    cp "$SCRIPT_DIR/wallpapers"/* "$TARGET_HOME/Pictures/wallpapers/"
    success "Wallpapers kopiert"
else
    warn "Kein Wallpaper gefunden — dunkle Hintergrundfarbe aktiv"
fi

# Autostart-Bloat deaktivieren
mkdir -p "$CONFIG_DIR/autostart"
for desktop in blueman-applet gnome-keyring-secrets gnome-keyring-pkcs11 gnome-keyring-ssh; do
    if [[ -f "/etc/xdg/autostart/${desktop}.desktop" ]]; then
        cp "/etc/xdg/autostart/${desktop}.desktop" "$CONFIG_DIR/autostart/"
        echo "Hidden=true" >> "$CONFIG_DIR/autostart/${desktop}.desktop"
    fi
done

# gnome-keyring aus PAM entfernen — startet sonst beim Login
sed -i 's/^password.*pam_gnome_keyring.so/# &/' /etc/pam.d/common-password 2>/dev/null || true

# snowfox CLI
cp "$SCRIPT_DIR/snowfox" /usr/local/bin/snowfox
chmod +x /usr/local/bin/snowfox
success "snowfox CLI installiert"

# snowfox Greeting
cp "$SCRIPT_DIR/snowfox-greeting.sh" /usr/local/bin/snowfox-greeting
chmod +x /usr/local/bin/snowfox-greeting

# Greeting in bashrc einbinden
BASHRC="$TARGET_HOME/.bashrc"
if ! grep -q "snowfox-greeting" "$BASHRC" 2>/dev/null; then
    echo '' >> "$BASHRC"
    echo '# SnowFoxOS Greeting' >> "$BASHRC"
    echo '[[ -x /usr/local/bin/snowfox-greeting ]] && snowfox-greeting' >> "$BASHRC"
fi
success "Terminal Greeting eingerichtet"

# Ollama (Offline-KI)
echo ""
read -rp "$(echo -e ${PURPLE}${BOLD}"[SnowFox] Ollama + llama3.2 installieren? (Offline-KI, ca. 2GB) [j/n]: "${RESET})" INSTALL_OLLAMA
if [[ "$INSTALL_OLLAMA" == "j" || "$INSTALL_OLLAMA" == "J" ]]; then
    info "Ollama wird installiert..."
    curl -fsSL https://ollama.com/install.sh | sh 2>/dev/null && \
        success "Ollama installiert" || \
        warn "Ollama konnte nicht installiert werden — manuell: curl -fsSL https://ollama.com/install.sh | sh"

    if command -v ollama &>/dev/null; then
        info "llama3.2 wird heruntergeladen (ca. 2GB)..."
        sudo -u "$TARGET_USER" ollama pull llama3.2 2>/dev/null && \
            success "llama3.2 bereit — starte mit: snowfox ai" || \
            warn "llama3.2 konnte nicht geladen werden — manuell: ollama pull llama3.2"
    fi
else
    info "Ollama übersprungen — später installierbar mit: curl -fsSL https://ollama.com/install.sh | sh"
fi

# Berechtigungen
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
echo -e "${GRAY}  Browser:    ${BOLD}Brave${RESET}"
echo -e "${GRAY}  Audio:      ${BOLD}PipeWire${RESET}"
echo -e "${GRAY}  Darkmode:   ${BOLD}GTK3 + GTK4${RESET}"
echo -e "${GRAY}  Portal:     ${BOLD}xdg-desktop-portal-wlr${RESET}"
echo -e "${GRAY}  KI:         ${BOLD}Ollama + llama3.2 (offline)${RESET}"
echo -e "${GRAY}  CLI:        ${BOLD}snowfox${RESET}"
echo -e "${GRAY}  GPU:        ${BOLD}$(
    $IS_HYBRID && echo "Hybrid (AMD + Nvidia) → Nvidia-Modus aktiv" || \
    { $HAS_NVIDIA && echo "Nvidia"; } || \
    { $HAS_AMD && echo "AMD"; } || \
    echo "Intel/andere"
)${RESET}"
echo -e "${GRAY}  zram:       ${BOLD}aktiv (lz4, 50%)${RESET}"
echo -e "${GRAY}  swappiness: ${BOLD}10 (RAM-bevorzugend)${RESET}"
echo -e "${GRAY}  Login:      ${BOLD}TTY1 → Passwort → Sway${RESET}"
echo ""
echo -e "${ORANGE}${BOLD}  Shortcuts:${RESET}"
echo -e "  ${GRAY}Super+Return   ${RESET}Terminal"
echo -e "  ${GRAY}Super+Space    ${RESET}App-Launcher (Wofi)"
echo -e "  ${GRAY}Super+B        ${RESET}Brave Browser"
echo -e "  ${GRAY}Super+E        ${RESET}Dateimanager"
echo -e "  ${GRAY}Super+L        ${RESET}Bildschirm sperren"
echo -e "  ${GRAY}Super+Shift+E  ${RESET}Power-Menü"
echo ""
if $IS_HYBRID; then
    echo -e "${ORANGE}${BOLD}  ⚠ Hybrid-GPU: Alle Monitore an die Nvidia-Karte anschließen!${RESET}"
    echo -e "${GRAY}     Motherboard-Ausgänge (iGPU) sind deaktiviert.${RESET}"
    echo ""
fi
echo -e "${ORANGE}${BOLD}  → Neu starten: sudo reboot${RESET}"
echo ""
