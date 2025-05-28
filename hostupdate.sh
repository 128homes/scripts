#!/bin/bash

# Discord Webhook URL hier einfügen
DISCORD_WEBHOOK_URL="url"

send_discord_message() {
    local message=$1
    # Einfaches JSON Escape für Anführungszeichen und Zeilenumbrüche
    local escaped_message=$(echo "$message" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    curl -s -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\":\"${escaped_message}\"}" \
         "$DISCORD_WEBHOOK_URL"
}

log_and_notify() {
    local message="$1"
    echo "$message"
    send_discord_message "$message"
}

stop_lxc_containers() {
    log_and_notify "Stoppe alle laufenden LXC Container..."
    pct list | awk 'NR>1 && $2=="running" {print $1}' | while read -r ct; do
        log_and_notify "Stoppe Container $ct..."
        if ! pct stop "$ct"; then
            log_and_notify "❌ Fehler beim Stoppen des Containers $ct"
        fi
    done
}

stop_vms() {
    log_and_notify "Stoppe alle laufenden VMs (sauber)..."
    qm list | awk 'NR>1 && $2=="running" {print $1}' | while read -r vm; do
        log_and_notify "Starte sauberes Herunterfahren von VM $vm..."
        if ! qm shutdown "$vm"; then
            log_and_notify "❌ Fehler beim Herunterfahren der VM $vm"
        fi
    done

    # Warten bis alle VMs aus sind oder Timeout (60 Sekunden)
    local retries=12
    for ((i=1; i<=retries; i++)); do
        local running_vms
        running_vms=$(qm list | awk 'NR>1 && $2=="running" {print $1}' | wc -l)
        if [ "$running_vms" -eq 0 ]; then
            log_and_notify "Alle VMs sind heruntergefahren."
            break
        fi
        log_and_notify "Noch laufende VMs: $running_vms. Warte 5 Sekunden..."
        sleep 5
    done

    # Harte Stopps, falls nötig
    local running_vms_list
    running_vms_list=$(qm list | awk 'NR>1 && $2=="running" {print $1}')
    if [ -n "$running_vms_list" ]; then
        for vm in $running_vms_list; do
            log_and_notify "VM $vm reagiert nicht, stoppe hart..."
            if ! qm stop "$vm"; then
                log_and_notify "❌ Fehler beim harten Stoppen der VM $vm"
            fi
        done
    fi
}

wait_until_stopped() {
    local timeout=120  # Gesamtzeit in Sekunden
    local interval=5
    local elapsed=0

    while [ $elapsed -lt $timeout ]; do
        local running_containers running_vms
        running_containers=$(pct list | awk 'NR>1 && $2=="running" {print $1}' | wc -l)
        running_vms=$(qm list | awk 'NR>1 && $2=="running" {print $1}' | wc -l)
        if [ "$running_containers" -eq 0 ] && [ "$running_vms" -eq 0 ]; then
            log_and_notify "Alle VMs und Container gestoppt."
            return 0
        fi
        log_and_notify "Noch laufende VMs: $running_vms, Container: $running_containers. Warte $interval Sekunden..."
        sleep $interval
        elapsed=$((elapsed + interval))
    done

    log_and_notify "⏰ Timeout erreicht, noch laufen VMs oder Container."
    return 1
}

echo "Starte Systemupdate..."

apt update

# Simuliere Upgrade und checke, ob Pakete aktualisiert würden
UPGRADE_CHECK=$(apt-get -s upgrade | grep -E '^([0-9]+) upgraded')

if echo "$UPGRADE_CHECK" | grep -q '^0 upgraded'; then
    log_and_notify "✅ Kein Update verfügbar, kein Neustart erforderlich."
else
    if apt full-upgrade -y; then
        log_and_notify "Systemupdate erfolgreich abgeschlossen."
        if [ -f /var/run/reboot-required ]; then
            log_and_notify "🔔 Server Updates abgeschlossen. Neustart erforderlich. Fahren alle VMs und Container runter..."
            stop_lxc_containers
            stop_vms

            log_and_notify "Warte, bis alle VMs und Container gestoppt sind..."
            wait_until_stopped

            log_and_notify "🔄 Server wird jetzt neu gestartet."
            reboot
        else
            log_and_notify "✅ Server Updates abgeschlossen. Kein Neustart erforderlich."
        fi
    else
        log_and_notify "❌ FEHLER: Systemupdate fehlgeschlagen! Bitte manuell prüfen."
        exit 1
    fi
fi
