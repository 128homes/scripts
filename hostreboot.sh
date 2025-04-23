#!/bin/bash

# Definiere die maximale Wartezeit (30 Minuten = 1800 Sekunden)
max_wartezeit=1800
wartedauer=30
vergangene_zeit=0

# Discord Webhook URL
webhook_url="[webhookurl]"

# Funktion zum Senden von Nachrichten an Discord
send_discord_message() {
    local message="$1"
    curl -s -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"$message\"}" \
         "$webhook_url" > /dev/null
}

# Endlosschleife zur regelmäßigen Überprüfung
while true; do
    # Status von Container 101 und 102 prüfen
    container_101_laeuft=$(pct status 101 | grep -qi "running" && echo 1 || echo 0)
    container_102_laeuft=$(pct status 102 | grep -qi "running" && echo 1 || echo 0)

    if [ "$container_101_laeuft" -eq 0 ] && [ "$container_102_laeuft" -eq 0 ]; then
        send_discord_message "✅ Container 101 und 102 sind gestoppt. Fahre Container 100 herunter..."
        
        # Optional: Prüfen, ob Container 100 läuft
        if pct status 100 | grep -qi "running"; then
            pct shutdown 100
            send_discord_message "🛑 Container 100 wurde heruntergefahren."
        else
            send_discord_message "ℹ️ Container 100 war bereits gestoppt."
        fi

        send_discord_message "📦 Führe jetzt Host-Updates durch..."
        apt update && apt full-upgrade -y

        send_discord_message "✅ Updates abgeschlossen. Starte Host neu..."
        reboot now
        exit 0
    else
        send_discord_message "⏳ Container 101 oder 102 laufen noch. Warte $wartedauer Sekunden..."
        sleep $wartedauer
        vergangene_zeit=$((vergangene_zeit + wartedauer))
    fi

    if [ "$vergangene_zeit" -ge "$max_wartezeit" ]; then
        send_discord_message "❌ Maximale Wartezeit erreicht. Vorgang wird abgebrochen."
        exit 1
    fi
done
