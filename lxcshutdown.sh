#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

WEBHOOK_URL="[webhookurl]"

# Update starten
apt update
apt full-upgrade -y

# Discord Nachricht schicken
curl -H "Content-Type: application/json" \
     -X POST \
     -d "{\"content\": \"✅ LXC101 wurde erfolgreich aktualisiert. Fahre jetzt runter.\"}" \
     "$WEBHOOK_URL"

# Server runterfahren
reboot now
