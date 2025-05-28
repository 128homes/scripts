#!/bin/bash

DISCORD_WEBHOOK_URL="url"

send_discord_message() {
    local message=$1
    # JSON escaping rudimentär (nur Anführungszeichen und Backslash)
    local json_message=$(echo "$message" | sed 's/\\/\\\\/g; s/"/\\"/g')
    curl -s -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\":\"${json_message}\"}" \
         "$DISCORD_WEBHOOK_URL" > /dev/null
}

echo "Prüfe auf Updates..."

if ! apt update -qq > /dev/null 2>&1; then
    send_discord_message "❗ Fehler bei apt update auf $(hostname)."
    exit 1
fi

UPDATES_AVAILABLE=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." | grep -c .)

if [ "$UPDATES_AVAILABLE" -eq 0 ]; then
    echo "Keine Updates verfügbar."
    send_discord_message "🟢 Keine Updates verfügbar. System ist aktuell."
    exit 0
fi

echo "Updates verfügbar. Starte full-upgrade..."

if ! apt full-upgrade -y; then
    send_discord_message "❗ Fehler beim Ausführen von apt full-upgrade."
    exit 1
fi

if [ -f /var/run/reboot-required ]; then
    send_discord_message "🔔 Updates wurden installiert. Neustart erforderlich. Server wird neu gestartet..."
    reboot
else
    send_discord_message "✅ Updates installiert. Kein Neustart erforderlich."
fi
