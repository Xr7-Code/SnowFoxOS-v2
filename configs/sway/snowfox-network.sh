#!/bin/bash
# ============================================================
#  SnowFoxOS — Netzwerk-Manager via Wofi
# ============================================================

# Verfügbare WLANs scannen
NETWORKS=$(nmcli -f SSID,SIGNAL,SECURITY,IN-USE device wifi list 2>/dev/null | tail -n +2 | awk '
{
    inuse = ($4 == "*") ? "✓ " : "  "
    security = ($3 == "--") ? "OPEN" : $3
    printf "%s%-35s %3s%%  %s\n", inuse, $1, $2, security
}')

if [[ -z "$NETWORKS" ]]; then
    notify-send "SnowFox Netzwerk" "Keine WLANs gefunden — ist WiFi aktiv?"
    exit 1
fi

# Zusätzliche Optionen
EXTRAS="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Ethernet-Status
  WiFi an/aus
  Verbindung trennen
  Netzwerk-Details"

CHOICE=$(echo -e "$NETWORKS\n$EXTRAS" | wofi --show dmenu \
    --prompt "Netzwerk" \
    --width 500 \
    --height 400 \
    --insensitive)

[[ -z "$CHOICE" ]] && exit 0

# Auswahl verarbeiten
case "$CHOICE" in
    *"WiFi an/aus"*)
        STATE=$(nmcli radio wifi)
        if [[ "$STATE" == "enabled" ]]; then
            nmcli radio wifi off
            notify-send "🦊 SnowFox" "WiFi deaktiviert"
        else
            nmcli radio wifi on
            notify-send "🦊 SnowFox" "WiFi aktiviert"
        fi
        ;;
    *"Verbindung trennen"*)
        ACTIVE=$(nmcli -t -f NAME connection show --active | head -1)
        if [[ -n "$ACTIVE" ]]; then
            nmcli connection down "$ACTIVE"
            notify-send "🦊 SnowFox" "Getrennt von: $ACTIVE"
        else
            notify-send "🦊 SnowFox" "Keine aktive Verbindung"
        fi
        ;;
    *"Ethernet-Status"*)
        ETH=$(nmcli device status | grep ethernet)
        notify-send "🦊 SnowFox Ethernet" "$ETH"
        ;;
    *"Netzwerk-Details"*)
        INFO=$(nmcli device show | grep -E "GENERAL.DEVICE|GENERAL.STATE|IP4.ADDRESS|IP4.GATEWAY" | head -12)
        notify-send "🦊 SnowFox Netzwerk" "$INFO"
        ;;
    *"━━━"*)
        exit 0
        ;;
    *)
        # SSID extrahieren
        SSID=$(echo "$CHOICE" | sed 's/^[✓ ]*//' | awk '{print $1}' | xargs)
        [[ -z "$SSID" ]] && exit 0

        # Prüfen ob bereits verbunden
        CURRENT=$(nmcli -t -f active,ssid dev wifi | grep "^yes" | cut -d: -f2)
        if [[ "$CURRENT" == "$SSID" ]]; then
            # Bereits verbunden — Captive Portal prüfen
            CAPTIVE=$(curl -s --max-time 3 -o /dev/null -w "%{http_code}" http://detectportal.firefox.com/success.txt)
            if [[ "$CAPTIVE" != "200" ]]; then
                notify-send "🦊 SnowFox" "Captive Portal erkannt — Browser wird geöffnet"
                brave-browser "http://detectportal.firefox.com/success.txt" &
            else
                notify-send "🦊 SnowFox" "Bereits verbunden mit: $SSID"
            fi
            exit 0
        fi

        # Sicherheit des gewählten Netzwerks prüfen
        SECURITY=$(nmcli -f SSID,SECURITY device wifi list | grep "^${SSID} " | awk '{print $NF}' | head -1)

        # Bekannte Verbindung
        if nmcli connection show "$SSID" &>/dev/null; then
            nmcli connection up "$SSID" && \
                notify-send "🦊 SnowFox" "Verbunden mit: $SSID" || \
                notify-send "🦊 SnowFox" "Verbindung fehlgeschlagen"

        # Offenes Netzwerk (kein Passwort)
        elif [[ "$SECURITY" == "--" || "$CHOICE" == *"OPEN"* ]]; then
            notify-send "🦊 SnowFox" "Verbinde mit offenem Netzwerk: $SSID"
            nmcli device wifi connect "$SSID" && {
                sleep 2
                # Captive Portal prüfen und Browser öffnen
                CAPTIVE=$(curl -s --max-time 3 -o /dev/null -w "%{http_code}" http://detectportal.firefox.com/success.txt)
                if [[ "$CAPTIVE" != "200" ]]; then
                    notify-send "🦊 SnowFox" "Captive Portal erkannt — Browser wird geöffnet"
                    brave-browser "http://captive.apple.com" &
                else
                    notify-send "🦊 SnowFox" "Verbunden mit: $SSID"
                fi
            } || notify-send "🦊 SnowFox" "Verbindung fehlgeschlagen"

        # Verschlüsseltes Netzwerk — Passwort abfragen
        else
            PASS=$(echo "" | wofi --show dmenu \
                --prompt "Passwort für $SSID" \
                --width 400 --height 100 \
                --password)

            if [[ -n "$PASS" ]]; then
                nmcli device wifi connect "$SSID" password "$PASS" && \
                    notify-send "🦊 SnowFox" "Verbunden mit: $SSID" || \
                    notify-send "🦊 SnowFox" "Verbindung fehlgeschlagen — falsches Passwort?"
            else
                # Leeres Passwort — als offenes Netzwerk behandeln
                nmcli device wifi connect "$SSID" && \
                    notify-send "🦊 SnowFox" "Verbunden mit: $SSID" || \
                    notify-send "🦊 SnowFox" "Verbindung fehlgeschlagen"
            fi
        fi
        ;;
esac
