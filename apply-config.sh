#!/bin/bash
# ============================================================
#  SnowFoxOS v2.0 — Konfiguration anwenden
#  Dieses Script in einem XFCE-Terminal ausführen:
#  bash apply-config.sh
#  (KEIN sudo nötig!)
# ============================================================

PURPLE='\033[0;35m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
RESET='\033[0m'
BOLD='\033[1m'

info()    { echo -e "${PURPLE}${BOLD}[SnowFox]${RESET} $1"; }
success() { echo -e "${GREEN}${BOLD}[  OK  ]${RESET} $1"; }
warn()    { echo -e "${ORANGE}${BOLD}[ WARN ]${RESET} $1"; }

# XFCE muss laufen
if ! pgrep -x "xfce4-session" > /dev/null; then
    echo "Dieses Script muss innerhalb einer laufenden XFCE-Session ausgeführt werden."
    echo "Öffne ein Terminal in XFCE und führe es erneut aus."
    exit 1
fi

echo ""
echo -e "${PURPLE}${BOLD}  SnowFoxOS — Konfiguration wird angewendet...${RESET}"
echo ""

# ============================================================
# SCHRITT 1 — Altes Panel komplett löschen & neu aufbauen
# ============================================================
info "Panel wird zurückgesetzt..."

# Alle bestehenden Panel-Plugins entfernen
xfconf-query -c xfce4-panel -p /panels -r -R 2>/dev/null || true
sleep 1

# Panel 1 anlegen
xfconf-query -c xfce4-panel -p /panels -n -t int -s 1

# Panel-Eigenschaften setzen
xfconf-query -c xfce4-panel -p /panels/panel-1/size              -n -t int    -s 36
xfconf-query -c xfce4-panel -p /panels/panel-1/length            -n -t uint   -s 100
xfconf-query -c xfce4-panel -p /panels/panel-1/length-adjust     -n -t bool   -s true
xfconf-query -c xfce4-panel -p /panels/panel-1/position          -n -t string -s "p=6;x=0;y=0"
xfconf-query -c xfce4-panel -p /panels/panel-1/position-locked   -n -t bool   -s false
xfconf-query -c xfce4-panel -p /panels/panel-1/span-monitors     -n -t bool   -s false
xfconf-query -c xfce4-panel -p /panels/panel-1/mode              -n -t uint   -s 0
xfconf-query -c xfce4-panel -p /panels/panel-1/nrows             -n -t uint   -s 1
xfconf-query -c xfce4-panel -p /panels/panel-1/background-style  -n -t uint   -s 1
xfconf-query -c xfce4-panel -p /panels/panel-1/background-rgba   -n -t double -s 0.1 \
                                                                     -t double -s 0.1 \
                                                                     -t double -s 0.1 \
                                                                     -t double -s 0.95
xfconf-query -c xfce4-panel -p /panels/panel-1/enter-opacity     -n -t uint   -s 100
xfconf-query -c xfce4-panel -p /panels/panel-1/leave-opacity     -n -t uint   -s 100

# Plugin-IDs zuweisen:
# 1=whiskermenu, 2=separator, 3=tasklist, 4=separator(expand), 5=systray, 6=pulseaudio, 7=clock
xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids \
    -n -t int -s 1 \
       -t int -s 2 \
       -t int -s 3 \
       -t int -s 4 \
       -t int -s 5 \
       -t int -s 6 \
       -t int -s 7

# Plugin-Typen definieren
xfconf-query -c xfce4-panel -p /plugins/plugin-1 -n -t string -s "whiskermenu"
xfconf-query -c xfce4-panel -p /plugins/plugin-2 -n -t string -s "separator"
xfconf-query -c xfce4-panel -p /plugins/plugin-3 -n -t string -s "tasklist"
xfconf-query -c xfce4-panel -p /plugins/plugin-4 -n -t string -s "separator"
xfconf-query -c xfce4-panel -p /plugins/plugin-5 -n -t string -s "systray"
xfconf-query -c xfce4-panel -p /plugins/plugin-6 -n -t string -s "pulseaudio"
xfconf-query -c xfce4-panel -p /plugins/plugin-7 -n -t string -s "clock"

# Separator 2 — normaler Trenner
xfconf-query -c xfce4-panel -p /plugins/plugin-2/style   -n -t uint -s 0
xfconf-query -c xfce4-panel -p /plugins/plugin-2/expand  -n -t bool -s false

# Tasklist — Fenster anzeigen
xfconf-query -c xfce4-panel -p /plugins/plugin-3/show-labels      -n -t bool -s true
xfconf-query -c xfce4-panel -p /plugins/plugin-3/grouping         -n -t uint -s 1
xfconf-query -c xfce4-panel -p /plugins/plugin-3/show-handle      -n -t bool -s false
xfconf-query -c xfce4-panel -p /plugins/plugin-3/include-all-workspaces -n -t bool -s false

# Separator 4 — expandierender Spacer (schiebt Uhr nach rechts)
xfconf-query -c xfce4-panel -p /plugins/plugin-4/style   -n -t uint -s 0
xfconf-query -c xfce4-panel -p /plugins/plugin-4/expand  -n -t bool -s true

# Uhr — Format: 14:30  Mi 01.01.2025
xfconf-query -c xfce4-panel -p /plugins/plugin-7/digital-format \
    -n -t string -s "%H:%M  %a %d.%m.%Y"
xfconf-query -c xfce4-panel -p /plugins/plugin-7/mode -n -t uint -s 1

success "Panel konfiguriert (oben, dunkel, mit Whisker + Uhr + Systray)"

# ============================================================
# SCHRITT 2 — Theme, Icons, Cursor, Schrift
# ============================================================
info "Theme & Aussehen wird gesetzt..."

# GTK Theme
xfconf-query -c xsettings -p /Net/ThemeName         -s "Adw-dark" 2>/dev/null || \
xfconf-query -c xsettings -p /Net/ThemeName         -s "Adwaita-dark" 2>/dev/null || \
xfconf-query -c xsettings -p /Net/ThemeName         -s "Greybird-dark" 2>/dev/null || true

# Falls Orchis installiert wurde
if [[ -d "/usr/share/themes/Orchis-Dark" ]]; then
    xfconf-query -c xsettings -p /Net/ThemeName -s "Orchis-Dark"
    success "Orchis-Dark Theme gesetzt"
fi

# Icons
xfconf-query -c xsettings -p /Net/IconThemeName     -s "Papirus-Dark"

# Cursor
xfconf-query -c xsettings -p /Net/CursorThemeName   -s "Bibata-Modern-Classic" 2>/dev/null || \
xfconf-query -c xsettings -p /Net/CursorThemeName   -s "Adwaita" 2>/dev/null || true
xfconf-query -c xsettings -p /Net/CursorThemeSize   -s 24

# Schriften
xfconf-query -c xsettings -p /Gtk/FontName          -s "Inter 10" 2>/dev/null || \
xfconf-query -c xsettings -p /Gtk/FontName          -s "Sans 10"
xfconf-query -c xsettings -p /Gtk/MonospaceFontName -s "Noto Mono 10" 2>/dev/null || \
xfconf-query -c xsettings -p /Gtk/MonospaceFontName -s "Monospace 10"

# Schrift-Rendering (schärfer)
xfconf-query -c xsettings -p /Xft/Antialias         -s 1
xfconf-query -c xsettings -p /Xft/Hinting           -s 1
xfconf-query -c xsettings -p /Xft/HintStyle         -s "hintslight"
xfconf-query -c xsettings -p /Xft/RGBA              -s "rgb"

# Sounds aus
xfconf-query -c xsettings -p /Net/EnableEventSounds        -s false
xfconf-query -c xsettings -p /Net/EnableInputFeedbackSounds -s false

success "Theme, Icons, Cursor gesetzt"

# ============================================================
# SCHRITT 3 — Window Manager
# ============================================================
info "Window Manager wird konfiguriert..."

xfconf-query -c xfwm4 -p /general/title_font        -s "Inter Bold 10" 2>/dev/null || \
xfconf-query -c xfwm4 -p /general/title_font        -s "Sans Bold 10"
xfconf-query -c xfwm4 -p /general/button_layout     -s "CMH|"
xfconf-query -c xfwm4 -p /general/use_compositing   -s true
xfconf-query -c xfwm4 -p /general/frame_opacity     -s 100
xfconf-query -c xfwm4 -p /general/inactive_opacity  -s 95
xfconf-query -c xfwm4 -p /general/show_frame_shadow -s true
xfconf-query -c xfwm4 -p /general/snap_to_border    -s true
xfconf-query -c xfwm4 -p /general/workspace_count   -s 4
xfconf-query -c xfwm4 -p /general/mousewheel_rollup -s false
xfconf-query -c xfwm4 -p /general/double_click_action -s "maximize"

# Titelleiste
xfconf-query -c xfwm4 -p /general/title_alignment   -s "center"

# XFWM Theme (passend zum GTK Theme)
if [[ -d "/usr/share/themes/Orchis-Dark" ]]; then
    xfconf-query -c xfwm4 -p /general/theme -s "Orchis-Dark"
else
    xfconf-query -c xfwm4 -p /general/theme -s "Default-hdpi" 2>/dev/null || \
    xfconf-query -c xfwm4 -p /general/theme -s "Default"
fi

success "Window Manager konfiguriert"

# ============================================================
# SCHRITT 4 — Desktop Hintergrund
# ============================================================
info "Desktop-Hintergrund wird gesetzt..."

# Hintergrundfarbe dunkel setzen (falls kein Wallpaper vorhanden)
xfconf-query -c xfce4-desktop -p /backdrop/single-workspace-mode -s true 2>/dev/null || true

# Alle Monitore/Workspaces mit dunklem Hintergrund belegen
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

# Wallpapers aus dem Repo verwenden falls vorhanden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WALLPAPER_DIR="$SCRIPT_DIR/wallpapers"
if [[ -d "$WALLPAPER_DIR" ]]; then
    WALLPAPER=$(ls "$WALLPAPER_DIR"/*.{jpg,png,jpeg} 2>/dev/null | head -1)
    if [[ -n "$WALLPAPER" ]]; then
        for key in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep "last-image"); do
            xfconf-query -c xfce4-desktop -p "$key" -s "$WALLPAPER" 2>/dev/null || true
        done
        success "Wallpaper gesetzt: $(basename "$WALLPAPER")"
    fi
else
    info "Kein Wallpaper-Ordner gefunden — dunkle Hintergrundfarbe aktiv"
fi

# ============================================================
# SCHRITT 5 — Picom neu starten
# ============================================================
info "Picom Compositor wird gestartet..."

pkill picom 2>/dev/null || true
sleep 0.5

PICOM_CONF="$HOME/.config/picom/picom.conf"
if [[ -f "$PICOM_CONF" ]]; then
    picom --config "$PICOM_CONF" -b
    success "Picom läuft"
else
    picom -b 2>/dev/null && success "Picom läuft (Standard-Konfiguration)" || \
    warn "Picom konnte nicht gestartet werden"
fi

# ============================================================
# SCHRITT 6 — Panel neu starten damit Änderungen greifen
# ============================================================
info "Panel wird neu gestartet..."

xfce4-panel --quit 2>/dev/null || true
sleep 1
xfce4-panel &
sleep 2

success "Panel neu gestartet"

# ============================================================
# SCHRITT 7 — Whisker Menü Grundkonfiguration
# ============================================================
info "Whisker Menü wird konfiguriert..."

mkdir -p "$HOME/.config/xfce4/panel"
cat > "$HOME/.config/xfce4/panel/whiskermenu-1.rc" << 'EOF'
button-icon-name=snowfox-start
button-single-row=false
show-button-title=false
show-button-icon=true
button-title=Menü
search-actions=2
recent-items-max=10
favorites-in-recent=true
position-search-alternate=true
position-commands-alternate=false
position-categories-alternate=true
position-categories-horizontal=false
stay-on-focus-out=false
profile-shape=1
confirm-session-command=true
menu-width=450
menu-height=530
menu-opacity=95
command-settings=xfce4-settings-manager
show-command-settings=true
command-lockscreen=xflock4
show-command-lockscreen=true
command-switchuser=gdmflexiserver
show-command-switchuser=false
command-logoutdialog=xfce4-session-logout
show-command-logoutdialog=true
command-logout=xfce4-session-logout --logout
show-command-logout=false
command-restart=xfce4-session-logout --reboot
show-command-restart=true
command-shutdown=xfce4-session-logout --halt
show-command-shutdown=true
command-suspend=xfce4-session-logout --suspend
show-command-suspend=true
command-hibernate=xfce4-session-logout --hibernate
show-command-hibernate=false
command-hybrid-sleep=xfce4-session-logout --hybrid-sleep
show-command-hybrid-sleep=false
EOF

success "Whisker Menü konfiguriert"

# ============================================================
# SCHRITT 8 — Terminal (xfce4-terminal) dunkel einstellen
# ============================================================
info "Terminal-Farben werden gesetzt..."

mkdir -p "$HOME/.config/xfce4/terminal"
cat > "$HOME/.config/xfce4/terminal/terminalrc" << 'EOF'
[Configuration]
FontName=Noto Mono 11
MiscAlwaysShowTabs=FALSE
MiscBell=FALSE
MiscBellUrgent=FALSE
MiscBordersDefault=TRUE
MiscCursorBlinks=FALSE
MiscCursorShape=TERMINAL_CURSOR_SHAPE_BLOCK
MiscDefaultGeometry=100x28
MiscInheritGeometry=FALSE
MiscMenubarDefault=FALSE
MiscMouseAutohide=FALSE
MiscMouseWheelZoom=TRUE
MiscToolbarDefault=FALSE
MiscConfirmClose=TRUE
MiscCycleTabs=TRUE
MiscTabCloseButtons=TRUE
MiscTabCloseMiddleClick=TRUE
MiscTabPosition=GTK_POS_TOP
MiscHighlightUrls=TRUE
MiscMiddleClickOpensUri=FALSE
MiscCopyOnSelect=FALSE
MiscShowRelaunchDialog=TRUE
MiscRewrapOnResize=TRUE
MiscUseShiftArrowsToScroll=FALSE
MiscSlimTabs=FALSE
MiscNewTabAdjacent=FALSE
MiscSearchDialogOpacity=100
MiscShowUnsafePasteDialog=TRUE
BackgroundMode=TERMINAL_BACKGROUND_SOLID
BackgroundDarkness=0.90
ColorForeground=#e8e8e8
ColorBackground=#0f0f0f
ColorCursor=#9B59B6
ColorPalette=#1a1a1a;#e05555;#5faf5f;#E67E22;#5f87af;#9B59B6;#5fafaf;#bcbcbc;#3a3a3a;#ff6e6e;#87d787;#ffd787;#87afd7;#c397d8;#87d7d7;#e8e8e8
TabActivityColor=#9B59B6
EOF

success "Terminal-Farben gesetzt (Lila Cursor, Orange Akzente)"

# ============================================================
# Fertig!
# ============================================================
echo ""
echo -e "${GREEN}${BOLD}  Konfiguration erfolgreich angewendet!${RESET}"
echo ""
echo -e "  ${PURPLE}Was wurde gesetzt:${RESET}"
echo "   • Panel oben — dunkel, mit Whisker-Menü, Uhr und Systray"
echo "   • Dark Theme (Orchis-Dark oder Adwaita-Dark)"
echo "   • Papirus-Dark Icons"
echo "   • Terminal: Lila/Orange Farbschema"
echo "   • Picom Compositor aktiv"
echo "   • 4 Workspaces"
echo ""
echo -e "  ${ORANGE}Falls das Panel noch falsch aussieht:${RESET}"
echo "   Abmelden → Neu anmelden — dann ist alles sauber geladen."
echo ""
