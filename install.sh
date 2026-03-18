#!/bin/bash
# ============================================================
#  SnowFoxOS v2.0 — Installer
#  Basis: Debian 12 (Bookworm) minimal + SSH + standard utils
#  Autor: Xr7-Code
# ============================================================

set -e  # Bei Fehler sofort abbrechen

# ------------------------------------------------------------
# Farben & Hilfsfunktionen
# ------------------------------------------------------------
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
step()    { echo -e "\n${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; \
            echo -e "${PURPLE}${BOLD}  $1${RESET}"; \
            echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"; }

# ------------------------------------------------------------
# Root-Check
# ------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    error "Dieses Script muss als root ausgeführt werden: sudo ./install.sh"
fi

# ------------------------------------------------------------
# Ziel-User ermitteln (der User der sudo aufgerufen hat)
# ------------------------------------------------------------
TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
    echo -e "${ORANGE}Für welchen Benutzer soll SnowFoxOS eingerichtet werden?${RESET}"
    read -rp "Benutzername: " TARGET_USER
fi
TARGET_HOME="/home/$TARGET_USER"

if [[ ! -d "$TARGET_HOME" ]]; then
    error "Home-Verzeichnis $TARGET_HOME nicht gefunden. Benutzer '$TARGET_USER' existiert nicht?"
fi

info "Installiere SnowFoxOS v2.0 für Benutzer: ${BOLD}$TARGET_USER${RESET}"
sleep 2

# ============================================================
# SCHRITT 1 — System aktualisieren & Grundpakete
# ============================================================
step "1/8 — System aktualisieren"

apt-get update -qq
apt-get upgrade -y
apt-get install -y \
    curl wget git unzip zip \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    pciutils \
    usbutils \
    htop \
    neofetch \
    bash-completion

success "System aktualisiert"

# ============================================================
# SCHRITT 2 — GPU-Erkennung & Treiber
# ============================================================
step "2/8 — GPU-Erkennung & Treiber"

GPU_INFO=$(lspci | grep -iE 'vga|3d|display')
HAS_NVIDIA=false
HAS_AMD=false
IS_HYBRID=false

if echo "$GPU_INFO" | grep -qi "nvidia"; then
    HAS_NVIDIA=true
    info "Nvidia GPU gefunden"
fi
if echo "$GPU_INFO" | grep -qi "amd\|radeon\|advanced micro"; then
    HAS_AMD=true
    info "AMD GPU gefunden"
fi
if $HAS_NVIDIA && $HAS_AMD; then
    IS_HYBRID=true
    warn "Hybrid-GPU erkannt (AMD + Nvidia) — envycontrol wird installiert"
fi

# AMD — open-source Treiber (meist schon im Kernel, nur firmware)
if $HAS_AMD; then
    apt-get install -y firmware-amd-graphics libgl1-mesa-dri mesa-vulkan-drivers
    success "AMD Treiber installiert"
fi

# Nvidia — proprietärer Treiber
if $HAS_NVIDIA; then
    # non-free Repo aktivieren falls nötig
    if ! grep -q "non-free" /etc/apt/sources.list; then
        sed -i 's/main$/main contrib non-free non-free-firmware/' /etc/apt/sources.list
        apt-get update -qq
    fi
    apt-get install -y nvidia-driver firmware-misc-nonfree
    success "Nvidia Treiber installiert"
fi

# Hybrid: envycontrol für einfaches Umschalten AMD/Nvidia/Hybrid
if $IS_HYBRID; then
    apt-get install -y python3 python3-pip
    pip3 install envycontrol --break-system-packages 2>/dev/null || \
        pip3 install envycontrol
    success "envycontrol installiert (Befehl: sudo envycontrol -s hybrid|nvidia|integrated)"
fi

# Kein dedizierter GPU? Intel-Fallback
if ! $HAS_NVIDIA && ! $HAS_AMD; then
    apt-get install -y libgl1-mesa-dri mesa-vulkan-drivers intel-microcode 2>/dev/null || true
    info "Intel/andere GPU — Mesa Fallback installiert"
fi

# ============================================================
# SCHRITT 3 — XFCE4 Desktop + LightDM
# ============================================================
step "3/8 — XFCE4 Desktop & Display Manager"

# Kern-Desktop — nur was wirklich gebraucht wird, kein Bloat
apt-get install -y \
    xfce4 \
    xfce4-terminal \
    xfce4-taskmanager \
    xfce4-screenshooter \
    xfce4-notifyd \
    xfce4-pulseaudio-plugin \
    xfce4-battery-plugin \
    xfce4-whiskermenu-plugin \
    thunar \
    thunar-archive-plugin \
    thunar-volman \
    gvfs \
    gvfs-backends

# Display Manager — leicht, schnell
apt-get install -y lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings

# Picom Compositor (Schatten, leichte Transparenz)
apt-get install -y picom

# Fonts
apt-get install -y \
    fonts-inter \
    fonts-noto \
    fonts-noto-color-emoji

success "XFCE4 + LightDM installiert"

# LightDM als Standard-Display-Manager setzen
systemctl enable lightdm
echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager

# ============================================================
# SCHRITT 4 — Audio, Netzwerk, Bluetooth
# ============================================================
step "4/8 — Audio, Netzwerk & Systemdienste"

apt-get install -y \
    pulseaudio \
    pavucontrol \
    network-manager \
    network-manager-gnome \
    nm-tray \
    rfkill

# Bluetooth — nur installieren wenn Hardware vorhanden
if rfkill list bluetooth 2>/dev/null | grep -q "Bluetooth"; then
    apt-get install -y blueman bluez
    success "Bluetooth-Support installiert"
else
    info "Kein Bluetooth gefunden — wird übersprungen"
fi

systemctl enable NetworkManager

success "Audio & Netzwerk fertig"

# ============================================================
# SCHRITT 5 — zram (RAM-Optimierung)
# ============================================================
step "5/8 — zram RAM-Optimierung"

apt-get install -y zram-tools

# zram konfigurieren: 50% des RAM als komprimierten Swap
cat > /etc/default/zramswap << 'EOF'
# SnowFoxOS zram Konfiguration
ALGO=lz4        # schnellster Algorithmus
PERCENT=50      # 50% des physischen RAMs
PRIORITY=100    # höhere Priorität als normaler Swap
EOF

systemctl enable zramswap

success "zram aktiviert (lz4, 50% RAM)"

# ============================================================
# SCHRITT 6 — Themes, Icons, Cursor
# ============================================================
step "6/8 — Themes, Icons & Cursor"

THEMES_DIR="/usr/share/themes"
ICONS_DIR="/usr/share/icons"

apt-get install -y \
    papirus-icon-theme \
    bibata-cursor-theme 2>/dev/null || \
    apt-get install -y papirus-icon-theme

# Orchis-Dark als GTK-Theme Basis herunterladen & anpassen
if [[ ! -d "$THEMES_DIR/Orchis-Dark" ]]; then
    info "Lade Orchis Theme herunter..."
    git clone --depth=1 https://github.com/vinceliuice/Orchis-theme.git /tmp/orchis-theme
    cd /tmp/orchis-theme
    bash install.sh -t purple -c dark -s standard --tweaks black 2>/dev/null || \
    bash install.sh --color dark 2>/dev/null || true
    cd -
    success "Orchis Dark Theme installiert"
fi

# SnowFoxOS GTK-Theme Farbanpassungen (Lila + Orange Akzente)
SNOWFOX_THEME_DIR="$THEMES_DIR/SnowFoxOS"
mkdir -p "$SNOWFOX_THEME_DIR/gtk-3.0"
mkdir -p "$SNOWFOX_THEME_DIR/gtk-4.0"

cat > "$SNOWFOX_THEME_DIR/gtk-3.0/gtk.css" << 'EOF'
/* SnowFoxOS — GTK3 Anpassungen */
@import url("resource:///org/gtk/libgtk/theme/Adwaita/gtk-contained-dark.css");

@define-color accent_color #9B59B6;
@define-color accent_bg_color #9B59B6;
@define-color accent_fg_color #ffffff;

/* Akzentfarbe Lila */
selection, *:selected {
    background-color: #9B59B6;
    color: #ffffff;
}

/* Orange Akzent für hover/aktiv */
button:hover {
    border-color: #E67E22;
}

/* Dunkler Hintergrund */
window, .background {
    background-color: #0f0f0f;
    color: #e8e8e8;
}

headerbar {
    background-color: #1a1a1a;
    border-bottom: 1px solid #2a2a2a;
}
EOF

cp "$SNOWFOX_THEME_DIR/gtk-3.0/gtk.css" "$SNOWFOX_THEME_DIR/gtk-4.0/gtk.css"

cat > "$SNOWFOX_THEME_DIR/index.theme" << 'EOF'
[Desktop Entry]
Type=X-GNOME-Metatheme
Name=SnowFoxOS
Comment=SnowFoxOS Dark Theme
Encoding=UTF-8

[X-GNOME-Metatheme]
GtkTheme=SnowFoxOS
MetacityTheme=SnowFoxOS
IconTheme=Papirus-Dark
CursorTheme=Bibata-Modern-Classic
ButtonLayout=close,minimize,maximize:
EOF

success "Themes & Icons bereit"

# ============================================================
# SCHRITT 7 — XFCE Konfiguration für den Benutzer
# ============================================================
step "7/8 — XFCE Standardkonfiguration"

CONFIG_DIR="$TARGET_HOME/.config"
mkdir -p "$CONFIG_DIR/xfce4/xfconf/xfce-perchannel-xml"

# GTK Theme & Fonts setzen
cat > "$CONFIG_DIR/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="SnowFoxOS"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
    <property name="CursorThemeName" type="string" value="Bibata-Modern-Classic"/>
    <property name="CursorThemeSize" type="int" value="24"/>
    <property name="EnableEventSounds" type="bool" value="false"/>
    <property name="EnableInputFeedbackSounds" type="bool" value="false"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Inter 10"/>
    <property name="MonospaceFontName" type="string" value="Noto Mono 10"/>
    <property name="CursorThemeName" type="string" value="Bibata-Modern-Classic"/>
    <property name="DecorationLayout" type="string" value="close,minimize,maximize:"/>
  </property>
  <property name="Xft" type="empty">
    <property name="Antialias" type="int" value="1"/>
    <property name="Hinting" type="int" value="1"/>
    <property name="HintStyle" type="string" value="hintslight"/>
    <property name="RGBA" type="string" value="rgb"/>
    <property name="DPI" type="int" value="96"/>
  </property>
</channel>
EOF

# Window Manager (xfwm4) — dunkel, minimalistisch
cat > "$CONFIG_DIR/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="SnowFoxOS"/>
    <property name="title_font" type="string" value="Inter Bold 10"/>
    <property name="button_layout" type="string" value="CMH|"/>
    <property name="frame_opacity" type="int" value="100"/>
    <property name="inactive_opacity" type="int" value="95"/>
    <property name="use_compositing" type="bool" value="true"/>
    <property name="show_dock_shadow" type="bool" value="false"/>
    <property name="show_frame_shadow" type="bool" value="true"/>
    <property name="snap_to_border" type="bool" value="true"/>
    <property name="snap_to_windows" type="bool" value="false"/>
    <property name="workspace_count" type="int" value="4"/>
    <property name="mousewheel_rollup" type="bool" value="false"/>
    <property name="double_click_action" type="string" value="maximize"/>
  </property>
</channel>
EOF

# XFCE4-Panel — oben, dunkel, schlank
cat > "$CONFIG_DIR/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
  </property>
  <property name="panel-1" type="empty">
    <property name="position" type="string" value="p=6;x=0;y=0"/>
    <property name="length" type="uint" value="100"/>
    <property name="position-locked" type="bool" value="false"/>
    <property name="size" type="uint" value="32"/>
    <property name="background-style" type="uint" value="1"/>
    <property name="background-color" type="string" value="#1a1a1aee"/>
    <property name="enter-opacity" type="uint" value="100"/>
    <property name="leave-opacity" type="uint" value="95"/>
    <property name="mode" type="uint" value="0"/>
    <property name="span-monitors" type="bool" value="false"/>
    <property name="plugin-ids" type="array">
      <value type="int" value="1"/>
      <value type="int" value="2"/>
      <value type="int" value="3"/>
      <value type="int" value="4"/>
      <value type="int" value="5"/>
      <value type="int" value="6"/>
      <value type="int" value="7"/>
    </property>
  </property>
  <!-- Plugin-Definitionen -->
  <property name="plugins" type="empty">
    <!-- Whisker Menü -->
    <property name="plugin-1" type="string" value="whiskermenu"/>
    <!-- Separator -->
    <property name="plugin-2" type="string" value="separator">
      <property name="expand" type="bool" value="false"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <!-- Offene Fenster / Taskbar -->
    <property name="plugin-3" type="string" value="tasklist">
      <property name="show-labels" type="bool" value="true"/>
      <property name="grouping" type="uint" value="1"/>
    </property>
    <!-- Spacer (füllt Mitte) -->
    <property name="plugin-4" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <!-- Systemtray -->
    <property name="plugin-5" type="string" value="systray"/>
    <!-- PulseAudio -->
    <property name="plugin-6" type="string" value="pulseaudio"/>
    <!-- Uhr -->
    <property name="plugin-7" type="string" value="clock">
      <property name="digital-format" type="string" value="%H:%M  %d.%m.%Y"/>
    </property>
  </property>
</channel>
EOF

# Picom Compositor — leicht, keine schweren Effekte
mkdir -p "$CONFIG_DIR/picom"
cat > "$CONFIG_DIR/picom/picom.conf" << 'EOF'
# SnowFoxOS — Picom Konfiguration (minimal & schnell)

# Rendering
backend = "glx";
glx-no-stencil = true;
glx-copy-from-front = false;
use-damage = true;

# Schatten — nur für Fenster, nicht Panel
shadow = true;
shadow-radius = 12;
shadow-opacity = 0.4;
shadow-offset-x = -8;
shadow-offset-y = -8;
shadow-exclude = [
    "class_g = 'xfce4-panel'",
    "class_g = 'xfce4-notifyd'",
    "_GTK_FRAME_EXTENTS@:c"
];

# Transparenz — inaktive Fenster minimal transparent
inactive-opacity = 0.96;
active-opacity = 1.0;
frame-opacity = 1.0;
inactive-opacity-override = false;

# Animationen aus (spart Ressourcen)
fading = false;

# VSync
vsync = true;

# Keine unnötigen Logs
log-level = "warn";
EOF

# Autostart — nur das Nötigste
mkdir -p "$CONFIG_DIR/autostart"

# Picom starten
cat > "$CONFIG_DIR/autostart/picom.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Picom
Exec=picom --config /home/USER/.config/picom/picom.conf -b
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
# Platzhalter ersetzen
sed -i "s|/home/USER/|$TARGET_HOME/|g" "$CONFIG_DIR/autostart/picom.desktop"

# Network Manager Tray
cat > "$CONFIG_DIR/autostart/nm-tray.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Network Manager Tray
Exec=nm-tray
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

# Autostart-Bloat deaktivieren
for bloat in \
    "xfce4-power-manager" \
    "blueman-applet" \
    "print-applet" \
    "geoclue-demo-agent"; do
    BLOAT_FILE="$CONFIG_DIR/autostart/${bloat}.desktop"
    if [[ -f "/etc/xdg/autostart/${bloat}.desktop" ]]; then
        cp "/etc/xdg/autostart/${bloat}.desktop" "$BLOAT_FILE" 2>/dev/null || true
        echo "Hidden=true" >> "$BLOAT_FILE"
    fi
done

success "XFCE Konfiguration geschrieben"

# ============================================================
# SCHRITT 8 — Standard-Apps & Wine
# ============================================================
step "8/8 — Standard-Apps & Wine"

# Browser
apt-get install -y firefox-esr

# Leichte Zusatztools
apt-get install -y \
    mousepad \
    ristretto \
    file-roller \
    xarchiver \
    gparted \
    baobab

# Wine — Windows .exe Kompatibilität
info "Installiere Wine..."
dpkg --add-architecture i386
apt-get update -qq
apt-get install -y wine wine32 wine64 2>/dev/null || \
    apt-get install -y wine 2>/dev/null || \
    warn "Wine konnte nicht installiert werden — manuell nachholen mit: apt install wine"

# .exe → Wine Rechtsklick-Integration für Thunar
mkdir -p "$TARGET_HOME/.config/Thunar"
cat > "/usr/share/applications/wine-run.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Mit Wine öffnen
Exec=wine %f
MimeType=application/x-ms-dos-executable;application/x-msi;application/x-msdos-program;
NoDisplay=false
StartupNotify=true
Icon=wine
EOF

update-desktop-database /usr/share/applications/ 2>/dev/null || true

success "Standard-Apps & Wine installiert"

# ============================================================
# SCHRITT 9 — Leicht-Modus Script
# ============================================================

info "Erstelle snowfox-lite (Leicht-Modus für alte Hardware)..."

cat > /usr/local/bin/snowfox-lite << 'EOF'
#!/bin/bash
# SnowFoxOS — Leicht-Modus für alte Hardware
# Verwendung: snowfox-lite [on|off|status]

LITE_FLAG="/tmp/.snowfox-lite-active"

case "$1" in
    on)
        echo "Aktiviere Leicht-Modus..."
        pkill picom 2>/dev/null || true
        xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
        xfconf-query -c xfwm4 -p /general/frame_opacity -s 100 2>/dev/null || true
        xfconf-query -c xfwm4 -p /general/inactive_opacity -s 100 2>/dev/null || true
        # Hintergrundbild auf einfache Farbe setzen
        xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVGA-1/workspace0/last-image -s "" 2>/dev/null || true
        touch "$LITE_FLAG"
        echo "Leicht-Modus aktiv. RAM-Verbrauch reduziert."
        ;;
    off)
        echo "Deaktiviere Leicht-Modus..."
        picom --config ~/.config/picom/picom.conf -b 2>/dev/null || true
        xfconf-query -c xfwm4 -p /general/use_compositing -s true 2>/dev/null || true
        rm -f "$LITE_FLAG"
        echo "Normaler Modus aktiv."
        ;;
    status)
        if [[ -f "$LITE_FLAG" ]]; then
            echo "Leicht-Modus: AKTIV"
        else
            echo "Leicht-Modus: INAKTIV (normaler Modus)"
        fi
        ;;
    *)
        echo "Verwendung: snowfox-lite [on|off|status]"
        ;;
esac
EOF

chmod +x /usr/local/bin/snowfox-lite
success "snowfox-lite verfügbar (Befehl: snowfox-lite on/off/status)"

# ============================================================
# Berechtigungen korrigieren
# ============================================================

chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config"

# ============================================================
# Unnötige Dienste deaktivieren
# ============================================================

info "Deaktiviere unnötige Dienste..."

for service in \
    "avahi-daemon" \
    "cups" \
    "cups-browsed" \
    "ModemManager" \
    "wpa_supplicant"; do
    systemctl disable "$service" 2>/dev/null && \
        info "  Deaktiviert: $service" || true
done

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
echo -e "${GRAY}  Benutzer:     ${BOLD}$TARGET_USER${RESET}"
echo -e "${GRAY}  GPU-Modus:    ${BOLD}$([ "$IS_HYBRID" = true ] && echo 'Hybrid (AMD + Nvidia)' || ([ "$HAS_NVIDIA" = true ] && echo 'Nvidia' || ([ "$HAS_AMD" = true ] && echo 'AMD' || echo 'Intel/andere')))${RESET}"
echo -e "${GRAY}  zram:         ${BOLD}aktiv (lz4, 50%)${RESET}"
echo -e "${GRAY}  Panel:        ${BOLD}oben (frei verschiebbar)${RESET}"
echo -e "${GRAY}  Leicht-Modus: ${BOLD}snowfox-lite on${RESET}"
echo ""
echo -e "${ORANGE}${BOLD}  → Bitte neu starten: sudo reboot${RESET}"
echo ""
