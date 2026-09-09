#!/bin/bash
# Flarum-Inhalte nach der Browser-Installation automatisiert anlegen.
# Voraussetzung: Forum ist erreichbar, Admin existiert.
# Aufruf: ./setup-content.sh (Flarum-Admin-Passwort per ENV oder Prompt)
# Das Skript ist idempotent: bereits vorhandene Tags/Gruppen/Diskussionen werden übersprungen.

set -e

BASE_URL="${FORUM_BASE_URL:-https://dlivr.it}"
ADMIN_USER="${FLARUM_ADMIN_USER:-admin}"
ADMIN_PASS="${FLARUM_ADMIN_PASSWORD:-}"

if [ -z "$ADMIN_PASS" ]; then
    read -rsp "Passwort für Flarum-Admin '${ADMIN_USER}': " ADMIN_PASS
    echo
fi

echo "[setup-content] Login als ${ADMIN_USER}..."
TOKEN_RESPONSE=$(curl -sS -X POST "${BASE_URL}/api/token" \
    -H "Content-Type: application/json" \
    -d "{\"identification\":\"${ADMIN_USER}\",\"password\":\"${ADMIN_PASS}\",\"remember\":true}")

TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*' | head -n1 | cut -d'"' -f4)
if [ -z "$TOKEN" ]; then
    echo "[setup-content] Login fehlgeschlagen: ${TOKEN_RESPONSE}" >&2
    exit 1
fi

AUTH="Authorization: Token ${TOKEN}"

# Hilfsfunktion: Prüft, ob ein Tag mit dem Slug bereits existiert
tag_exists() {
    local slug="$1"
    local response
    response=$(curl -gsS -X GET "${BASE_URL}/api/tags" \
        -H "$AUTH" -H "Content-Type: application/json")
    echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for tag in data.get('data', []):
    if tag.get('attributes', {}).get('slug') == '${slug}':
        sys.exit(0)
sys.exit(1)
" 2>/dev/null
}

# Hilfsfunktion: Prüft, ob eine Gruppe mit dem Namen bereits existiert
group_exists() {
    local name="$1"
    local response
    response=$(curl -gsS -X GET "${BASE_URL}/api/groups" \
        -H "$AUTH" -H "Content-Type: application/json")
    echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for group in data.get('data', []):
    attr = group.get('attributes', {})
    if attr.get('nameSingular') == '${name}' or attr.get('namePlural') == '${name}s':
        sys.exit(0)
sys.exit(1)
" 2>/dev/null
}

# Hilfsfunktion: Prüft, ob eine Diskussion mit dem Titel bereits existiert
discussion_exists() {
    local title="$1"
    local response
    response=$(curl -gsS -X GET "${BASE_URL}/api/discussions" \
        -H "$AUTH" -H "Content-Type: application/json")
    echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for d in data.get('data', []):
    if d.get('attributes', {}).get('title') == '${title}':
        sys.exit(0)
sys.exit(1)
" 2>/dev/null
}

create_tag() {
    local slug="$1"
    local color="$2"
    local desc="$3"
    if tag_exists "$slug"; then
        echo "[setup-content] Tag '${slug}' existiert bereits, überspringe."
        return 0
    fi
    local payload
    payload=$(printf '{"data":{"type":"tags","attributes":{"name":"%s","slug":"%s","description":"%s","color":"%s","isHidden":false}}}' "$slug" "$slug" "$desc" "$color")
    echo "[setup-content] Erstelle Tag '${slug}'..."
    curl -sS -X POST "${BASE_URL}/api/tags" \
        -H "$AUTH" -H "Content-Type: application/json" \
        -d "$payload" || echo "  (fehlgeschlagen)"
}

create_group() {
    local name="$1"
    local color="$2"
    local icon="$3"
    if group_exists "$name"; then
        echo "[setup-content] Gruppe '${name}' existiert bereits, überspringe."
        return 0
    fi
    local payload
    payload=$(printf '{"data":{"type":"groups","attributes":{"nameSingular":"%s","namePlural":"%ss","color":"%s","icon":"%s"}}}' "$name" "$name" "$color" "$icon")
    echo "[setup-content] Erstelle Gruppe '${name}'..."
    curl -sS -X POST "${BASE_URL}/api/groups" \
        -H "$AUTH" -H "Content-Type: application/json" \
        -d "$payload" || echo "  (fehlgeschlagen)"
}

get_tag_id() {
    local slug="$1"
    local response
    response=$(curl -gsS -X GET "${BASE_URL}/api/tags" \
        -H "$AUTH" -H "Content-Type: application/json")
    echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for tag in data.get('data', []):
    if tag.get('attributes', {}).get('slug') == '${slug}':
        print(tag.get('id'))
        break
"
}

create_discussion() {
    local title="$1"
    local tag_id="$2"
    local content="$3"
    if discussion_exists "$title"; then
        echo "[setup-content] Diskussion '${title}' existiert bereits, überspringe."
        return 0
    fi
    local payload
    payload=$(printf '{"data":{"type":"discussions","attributes":{"title":"%s","content":"%s"},"relationships":{"tags":{"data":[{"type":"tags","id":"%s"}]}}}}' "$title" "$content" "$tag_id")
    echo "[setup-content] Erstelle Diskussion '${title}'..."
    curl -sS -X POST "${BASE_URL}/api/discussions" \
        -H "$AUTH" -H "Content-Type: application/json" \
        -d "$payload" || echo "  (fehlgeschlagen)"
}

# --- Tags ---
create_tag "news" "#D32F2F" "Ankündigungen und News"
create_tag "public" "#1976D2" "Öffentlicher Bereich für Gäste"
create_tag "gaming" "#388E3C" "Gaming, Matches und Server"
create_tag "applications" "#FBC02D" "Bewerbungen"
create_tag "tech" "#7B1FA2" "Technik, Server und Entwicklung"
create_tag "internal" "#E64A19" "Clan-interne Themen"
create_tag "officers" "#5D4037" "Officer-Bereich"

# --- Gruppen ---
create_group "Clan Member" "#1976D2" "fas fa-users"
create_group "Officer" "#D32F2F" "fas fa-shield-alt"

# --- Tag-IDs für Diskussionen ermitteln ---
NEWS_ID=$(get_tag_id "news")
PUBLIC_ID=$(get_tag_id "public")

echo "[setup-content] Tag IDs: news=${NEWS_ID}, public=${PUBLIC_ID}"

if [ -z "$NEWS_ID" ] || [ -z "$PUBLIC_ID" ]; then
    echo "[setup-content] Konnte Tag-IDs nicht ermitteln. Breche ab." >&2
    exit 1
fi

# --- Erste Diskussionen ---
create_discussion "Willkommen bei dlivr.it" "$NEWS_ID" "<p>Willkommen im Forum! Hier findest du News, Ankündigungen und alles Wichtige rund um den Clan.</p>"
create_discussion "Regeln und Richtlinien" "$PUBLIC_ID" "<p>1. Sei respektvoll.<br/>2. Kein Spam.<br/>3. Bewerbungen bitte nur im Tag 'applications'.</p>"
create_discussion "Mumble-Anleitung" "$PUBLIC_ID" "<p>Verbinde dich mit <b>dlivr.it:64738</b>. Stell dich kurz vor oder beantrage im Forum die Clan-Mitgliedschaft für erweiterte Rechte.</p>"
create_discussion "IRC-Channel" "$PUBLIC_ID" "<p>Unser IRC-Channel ist <b>#dlivr</b> auf Libera.Chat. Der Bot 'dit-bot' zeigt Mumble-Events und Forum-News an.</p>"

echo "[setup-content] Fertig. Bitte Rechte/Permissions anschließend in der Admin-UI prüfen."
