#!/bin/bash
# ============================================================
#  SnowFoxOS v2.0 — Konfiguration anwenden
#  Ausführen im XFCE-Terminal (KEIN sudo!):
#  bash apply-config.sh
# ============================================================

PURPLE='\033[0;35m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'
BOLD='\033[1m'

info()    { echo -e "${PURPLE}${BOLD}[SnowFox]${RESET} $1"; }
success() { echo -e "${GREEN}${BOLD}[  OK  ]${RESET} $1"; }
warn()    { echo -e "${ORANGE}${BOLD}[ WARN ]${RESET} $1"; }
error()   { echo -e "${RED}${BOLD}[FEHLER]${RESET} $1"; }

# XFCE muss laufen
if ! pgrep -x "xfce4-session" > /dev/null; then
    error "Dieses Script muss innerhalb einer laufenden XFCE-Session ausgeführt werden."
    error "Öffne ein Terminal in XFCE und führe es erneut aus."
    exit 1
fi

echo ""
echo -e "${PURPLE}${BOLD}  SnowFoxOS — Konfiguration wird angewendet...${RESET}"
echo ""

# Hilfsfunktion: Property setzen oder neu anlegen
xfset() {
    local channel="$1"; local property="$2"; shift 2
    if xfconf-query -c "$channel" -p "$property" > /dev/null 2>&1; then
        xfconf-query -c "$channel" -p "$property" "$@"
    else
        xfconf-query -c "$channel" -p "$property" -n "$@"
    fi
}

# ============================================================
# SCHRITT 1 — Theme, Icons, Cursor, Schrift
# ============================================================
info "Theme & Aussehen wird gesetzt..."

if [[ -d "/usr/share/themes/Orchis-Purple-Dark" ]]; then
    xfset xsettings /Net/ThemeName   -t string -s "Orchis-Purple-Dark"
    xfset xfwm4 /general/theme       -t string -s "Orchis-Purple-Dark"
    success "Theme: Orchis-Purple-Dark"
elif [[ -d "/usr/share/themes/Adwaita-dark" ]]; then
    xfset xsettings /Net/ThemeName   -t string -s "Adwaita-dark"
    xfset xfwm4 /general/theme       -t string -s "Default"
    warn "Orchis nicht gefunden — Fallback: Adwaita-dark"
fi

xfset xsettings /Net/IconThemeName       -t string -s "Papirus-Dark"
xfset xsettings /Net/CursorThemeName     -t string -s "Adwaita"
xfset xsettings /Net/CursorThemeSize     -t int    -s 24

if fc-list | grep -qi "inter"; then
    xfset xsettings /Gtk/FontName         -t string -s "Inter 10"
else
    xfset xsettings /Gtk/FontName         -t string -s "Sans 10"
fi
if fc-list | grep -qi "noto mono"; then
    xfset xsettings /Gtk/MonospaceFontName -t string -s "Noto Mono 10"
else
    xfset xsettings /Gtk/MonospaceFontName -t string -s "Monospace 10"
fi

xfset xsettings /Xft/Antialias           -t int    -s 1
xfset xsettings /Xft/Hinting            -t int    -s 1
xfset xsettings /Xft/HintStyle          -t string -s "hintslight"
xfset xsettings /Xft/RGBA               -t string -s "rgb"
xfset xsettings /Net/EnableEventSounds          -t bool -s false
xfset xsettings /Net/EnableInputFeedbackSounds  -t bool -s false

success "Theme, Icons, Cursor, Schrift gesetzt"

# ============================================================
# SCHRITT 2 — Window Manager
# ============================================================
info "Window Manager wird konfiguriert..."

if fc-list | grep -qi "inter"; then
    xfset xfwm4 /general/title_font   -t string -s "Inter Bold 10"
else
    xfset xfwm4 /general/title_font   -t string -s "Sans Bold 10"
fi
xfset xfwm4 /general/title_alignment    -t string -s "center"
xfset xfwm4 /general/button_layout      -t string -s "CMH|"
xfset xfwm4 /general/use_compositing    -t bool   -s true
xfset xfwm4 /general/frame_opacity      -t int    -s 100
xfset xfwm4 /general/inactive_opacity   -t int    -s 95
xfset xfwm4 /general/show_frame_shadow  -t bool   -s true
xfset xfwm4 /general/snap_to_border     -t bool   -s true
xfset xfwm4 /general/workspace_count    -t int    -s 4
xfset xfwm4 /general/mousewheel_rollup  -t bool   -s false
xfset xfwm4 /general/double_click_action -t string -s "maximize"

success "Window Manager konfiguriert"

# ============================================================
# SCHRITT 3 — Panel komplett neu aufbauen
# ============================================================
info "Panel wird neu aufgebaut..."

xfce4-panel --quit 2>/dev/null || true
sleep 1

# Alte Plugin-Einträge aufräumen
for i in $(seq 1 20); do
    xfconf-query -c xfce4-panel -p /plugins/plugin-$i -r -R 2>/dev/null || true
done

# Panel-Grundeinstellungen
# Layout:
# [1:Whisker] [2:sep] [3:Firefox] [4:Terminal] [5:Thunar]
# [6:sep-expand] [7:Uhr] [8:sep-expand]
# [9:Helligkeit] [10:Akku] [11:Lautstärke] [12:Systray]

xfset xfce4-panel /panels                          -t int    -s 1
xfset xfce4-panel /panels/panel-1/size             -t int    -s 36
xfset xfce4-panel /panels/panel-1/length           -t uint   -s 100
xfset xfce4-panel /panels/panel-1/length-adjust    -t bool   -s false
xfset xfce4-panel /panels/panel-1/position         -t string -s "p=6;x=0;y=0"
xfset xfce4-panel /panels/panel-1/position-locked  -t bool   -s true
xfset xfce4-panel /panels/panel-1/span-monitors    -t bool   -s false
xfset xfce4-panel /panels/panel-1/mode             -t uint   -s 0
xfset xfce4-panel /panels/panel-1/nrows            -t uint   -s 1
xfset xfce4-panel /panels/panel-1/background-style -t uint   -s 1
xfconf-query -c xfce4-panel -p /panels/panel-1/background-rgba -n \
    -t double -s 0.08 \
    -t double -s 0.08 \
    -t double -s 0.08 \
    -t double -s 0.96 2>/dev/null || \
xfconf-query -c xfce4-panel -p /panels/panel-1/background-rgba \
    -t double -s 0.08 \
    -t double -s 0.08 \
    -t double -s 0.08 \
    -t double -s 0.96 2>/dev/null || true
xfset xfce4-panel /panels/panel-1/enter-opacity    -t uint   -s 100
xfset xfce4-panel /panels/panel-1/leave-opacity    -t uint   -s 100

# Plugin-IDs
xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids -n \
    -t int -s 1  \
    -t int -s 2  \
    -t int -s 3  \
    -t int -s 4  \
    -t int -s 5  \
    -t int -s 6  \
    -t int -s 7  \
    -t int -s 8  \
    -t int -s 9  \
    -t int -s 10 \
    -t int -s 11 \
    -t int -s 12 2>/dev/null || \
xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids \
    -t int -s 1  \
    -t int -s 2  \
    -t int -s 3  \
    -t int -s 4  \
    -t int -s 5  \
    -t int -s 6  \
    -t int -s 7  \
    -t int -s 8  \
    -t int -s 9  \
    -t int -s 10 \
    -t int -s 11 \
    -t int -s 12 2>/dev/null || true

# Plugin-Typen
xfset xfce4-panel /plugins/plugin-1  -t string -s "whiskermenu"
xfset xfce4-panel /plugins/plugin-2  -t string -s "separator"
xfset xfce4-panel /plugins/plugin-3  -t string -s "launcher"
xfset xfce4-panel /plugins/plugin-4  -t string -s "launcher"
xfset xfce4-panel /plugins/plugin-5  -t string -s "launcher"
xfset xfce4-panel /plugins/plugin-6  -t string -s "separator"
xfset xfce4-panel /plugins/plugin-7  -t string -s "clock"
xfset xfce4-panel /plugins/plugin-8  -t string -s "separator"
xfset xfce4-panel /plugins/plugin-9  -t string -s "brightness"
xfset xfce4-panel /plugins/plugin-10 -t string -s "battery"
xfset xfce4-panel /plugins/plugin-11 -t string -s "pulseaudio"
xfset xfce4-panel /plugins/plugin-12 -t string -s "systray"

# Separator 2 — normaler Trenner
xfset xfce4-panel /plugins/plugin-2/style   -t uint -s 0
xfset xfce4-panel /plugins/plugin-2/expand  -t bool -s false

# Separator 6 — expandierend links (schiebt Uhr in die Mitte)
xfset xfce4-panel /plugins/plugin-6/style   -t uint -s 0
xfset xfce4-panel /plugins/plugin-6/expand  -t bool -s true

# Separator 8 — expandierend rechts (schiebt Systray nach rechts)
xfset xfce4-panel /plugins/plugin-8/style   -t uint -s 0
xfset xfce4-panel /plugins/plugin-8/expand  -t bool -s true

# Uhr — nur Uhrzeit, mittig
xfset xfce4-panel /plugins/plugin-7/mode           -t uint   -s 1
xfset xfce4-panel /plugins/plugin-7/digital-format -t string -s "%H:%M"

# Akku
xfset xfce4-panel /plugins/plugin-10/show-percentage -t bool -s true
xfset xfce4-panel /plugins/plugin-10/show-remaining  -t bool -s false

# Lautstärke
xfset xfce4-panel /plugins/plugin-11/enable-keyboard-shortcuts -t bool -s true
xfset xfce4-panel /plugins/plugin-11/show-notifications        -t bool -s true

# Systray
xfset xfce4-panel /plugins/plugin-12/size-max     -t uint -s 22
xfset xfce4-panel /plugins/plugin-12/square-icons -t bool -s true

success "Panel-Einstellungen geschrieben"

# ── Launcher Desktop-Einträge ──────────────────────────────
info "Launcher werden erstellt..."

# Firefox
mkdir -p "$HOME/.config/xfce4/panel/launcher-3"
cat > "$HOME/.config/xfce4/panel/launcher-3/firefox.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Firefox
Exec=firefox-esr %u
Icon=firefox-esr
Categories=Network;WebBrowser;
EOF
xfset xfce4-panel /plugins/plugin-3/items -t string -s "firefox.desktop"

# Terminal
mkdir -p "$HOME/.config/xfce4/panel/launcher-4"
cat > "$HOME/.config/xfce4/panel/launcher-4/terminal.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Terminal
Exec=xfce4-terminal
Icon=utilities-terminal
Categories=System;TerminalEmulator;
EOF
xfset xfce4-panel /plugins/plugin-4/items -t string -s "terminal.desktop"

# Thunar
mkdir -p "$HOME/.config/xfce4/panel/launcher-5"
cat > "$HOME/.config/xfce4/panel/launcher-5/thunar.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Dateien
Exec=thunar
Icon=system-file-manager
Categories=System;FileManager;
EOF
xfset xfce4-panel /plugins/plugin-5/items -t string -s "thunar.desktop"

success "Launcher erstellt (Firefox, Terminal, Thunar)"

# ── Whisker Menü ───────────────────────────────────────────
info "Whisker Menü wird konfiguriert..."

mkdir -p "$HOME/.config/xfce4/panel"
cat > "$HOME/.config/xfce4/panel/whiskermenu-1.rc" << 'EOF'
button-icon-name=xfce4-whiskermenu
button-single-row=false
show-button-title=false
show-button-icon=true
search-actions=2
recent-items-max=10
position-search-alternate=true
position-categories-alternate=true
position-categories-horizontal=false
stay-on-focus-out=false
menu-width=450
menu-height=530
menu-opacity=95
show-command-settings=true
show-command-lockscreen=true
show-command-switchuser=false
show-command-logoutdialog=true
show-command-restart=true
show-command-shutdown=true
show-command-suspend=true
command-settings=xfce4-settings-manager
command-lockscreen=xflock4
command-logoutdialog=xfce4-session-logout
command-restart=xfce4-session-logout --reboot
command-shutdown=xfce4-session-logout --halt
command-suspend=xfce4-session-logout --suspend
EOF

success "Whisker Menü konfiguriert"

# ============================================================
# SCHRITT 4 — Desktop Hintergrund
# ============================================================
info "Desktop-Hintergrund wird gesetzt..."

for key in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep "color-style"); do
    xfconf-query -c xfce4-desktop -p "$key" -s 0 2>/dev/null || true
done
for key in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep "rgba1"); do
    xfconf-query -c xfce4-desktop -p "$key" \
        -t double -s 0.05 \
        -t double -s 0.05 \
        -t double -s 0.08 \
        -t double -s 1.0 2>/dev/null || true
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WALLPAPER=$(ls "$SCRIPT_DIR/wallpapers"/*.{jpg,png,jpeg} 2>/dev/null | head -1)
if [[ -n "$WALLPAPER" ]]; then
    for key in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep "last-image"); do
        xfconf-query -c xfce4-desktop -p "$key" -s "$WALLPAPER" 2>/dev/null || true
    done
    success "Wallpaper gesetzt: $(basename "$WALLPAPER")"
else
    info "Kein Wallpaper gefunden — dunkle Hintergrundfarbe aktiv"
fi

# ============================================================
# SCHRITT 5 — Terminal Farbschema
# ============================================================
info "Terminal-Farben werden gesetzt..."

mkdir -p "$HOME/.config/xfce4/terminal"
cat > "$HOME/.config/xfce4/terminal/terminalrc" << 'EOF'
[Configuration]
FontName=Noto Mono 11
MiscAlwaysShowTabs=FALSE
MiscBell=FALSE
MiscBordersDefault=TRUE
MiscCursorBlinks=FALSE
MiscCursorShape=TERMINAL_CURSOR_SHAPE_BLOCK
MiscDefaultGeometry=100x28
MiscMenubarDefault=FALSE
MiscConfirmClose=TRUE
MiscTabCloseButtons=TRUE
MiscHighlightUrls=TRUE
MiscRewrapOnResize=TRUE
BackgroundMode=TERMINAL_BACKGROUND_SOLID
ColorForeground=#e8e8e8
ColorBackground=#0f0f0f
ColorCursor=#9B59B6
ColorPalette=#1a1a1a;#e05555;#5faf5f;#E67E22;#5f87af;#9B59B6;#5fafaf;#bcbcbc;#3a3a3a;#ff6e6e;#87d787;#ffd787;#87afd7;#c397d8;#87d7d7;#e8e8e8
TabActivityColor=#9B59B6
EOF

success "Terminal: Lila/Orange Farbschema gesetzt"

# ============================================================
# SCHRITT 6 — Picom starten
# ============================================================
info "Picom Compositor wird gestartet..."

pkill picom 2>/dev/null || true
sleep 0.5

PICOM_CONF="$HOME/.config/picom/picom.conf"
if [[ -f "$PICOM_CONF" ]]; then
    picom --config "$PICOM_CONF" -b
    success "Picom läuft (eigene Konfiguration)"
else
    picom -b 2>/dev/null && success "Picom läuft (Standard)" || warn "Picom nicht gefunden"
fi

# ============================================================
# SCHRITT 7 — Autostart
# ============================================================
info "Autostart wird konfiguriert..."

mkdir -p "$HOME/.config/autostart"

cat > "$HOME/.config/autostart/picom.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Picom
Exec=picom --config $HOME/.config/picom/picom.conf -b
Hidden=false
X-GNOME-Autostart-enabled=true
EOF

cat > "$HOME/.config/autostart/nm-applet.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Network Manager
Exec=nm-applet
Hidden=false
X-GNOME-Autostart-enabled=true
EOF

if command -v blueman-applet &>/dev/null; then
    cat > "$HOME/.config/autostart/blueman.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Bluetooth
Exec=blueman-applet
Hidden=false
X-GNOME-Autostart-enabled=true
EOF
    success "Blueman Autostart eingerichtet"
fi

success "Autostart konfiguriert"

# ============================================================
# SCHRITT 8 — Panel starten
# ============================================================
info "Panel wird gestartet..."
xfce4-panel &
sleep 2

# ============================================================
# Fertig!
# ============================================================
echo ""
echo -e "${GREEN}${BOLD}  Konfiguration erfolgreich angewendet!${RESET}"
echo ""
echo -e "  ${PURPLE}Panel-Layout:${RESET}"
echo "   [Menü] [Firefox] [Terminal] [Thunar] ··· [14:30] ··· [Helligkeit] [Akku] [Lautstärke] [Systray]"
echo ""
echo -e "  ${ORANGE}Hinweis:${RESET} Falls etwas noch nicht stimmt →"
echo "   Abmelden und neu anmelden — dann lädt alles sauber."
echo ""
