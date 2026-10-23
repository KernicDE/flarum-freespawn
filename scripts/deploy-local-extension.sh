#!/usr/bin/env bash
# Spielt die lokale Erweiterung (local/extend.php + local/freespawn-links/) auf den Server ein - sicher:
#  1. PHP-Syntaxpruefung von extend.php (Abbruch bei Fehler, es wird nichts veraendert),
#  2. sichert die aktuelle extend.php lokal,
#  3. schreibt JS und extend.php in das Flarum-Verzeichnis, leert den Cache,
#  4. prueft Seite und Forum-JS und rollt bei Fehlern automatisch auf die alte extend.php zurueck.
# Aufruf: scripts/deploy-local-extension.sh [Backup-Verzeichnis]
set -euo pipefail

HOST="nicolas@kernic.net"
APP="flarum-app-freespawn"
SITE="https://freespawn.de"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL="$HERE/local"
BACKUPS="${1:-$HERE/../backups}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BACKUPS/extend.php.before-deploy-$STAMP"
BROWSER_LOG="$BACKUPS/deploy-browser-$STAMP.log"
mkdir -p "$BACKUPS"

put() {  # $1 = lokale Datei, $2 = Zielpfad im Container (als www-data)
  ssh "$HOST" "docker exec -u www-data -i $APP sh -c 'cat > $2'" < "$1"
}
# OPcache laeuft mit validate_timestamps=0: ohne Reload (USR2 an php-fpm, PID 1) bliebe der alte Code aktiv.
clear_cache() {
  ssh "$HOST" "docker exec -u www-data -w /var/www/html $APP php flarum cache:clear && docker exec $APP kill -USR2 1 && docker restart flarum-worker-freespawn" >/dev/null
}
# Laufzeit-Pruefung im ausgefuehrten DOM (jsdom, scripts/check-render.js). Ein Fehler im Forum-JS liefert weiter
# HTTP 200, die Seite ist dann aber leer - genau das faengt nur diese Pruefung ab.
# Rueckgabe: 0 = rendert (3 Links, Suchfeld, keine JS-Fehler), 1 = kaputt, 2 = nicht pruefbar (npm install fehlt)
rendered_ok() {
  [ -d "$HERE/scripts/node_modules/jsdom" ] || return 2
  local out rc=0
  out="$(timeout 60 node "$HERE/scripts/check-render.js" "$SITE/" 2>&1)" || rc=$?
  echo "$out" > "$BROWSER_LOG"
  [ "$rc" = 0 ] && return 0
  return 1
}
healthy() {
  local code js rc=0
  for path in / /tags /d/13-willkommen-bei-freespawn; do
    code="$(curl -s -o /dev/null -w '%{http_code}' "$SITE$path")"; [ "$code" = 200 ] || { echo "  $path -> HTTP $code"; return 1; }
  done
  js="$(curl -s "$SITE/" | grep -o "$SITE/assets/forum.js?v=[a-z0-9]*" | head -1)"
  local bundle=""; [ -n "$js" ] && bundle="$(curl -s "$js")"
  grep -q "freespawn-links" <<<"$bundle" || { echo "  forum.js enthaelt die Erweiterung nicht"; return 1; }
  rendered_ok || rc=$?
  case "$rc" in
    0) echo "  Render-Pruefung: Seite rendert (3 Links, Suchfeld, keine JS-Fehler)";;
    2) echo "  WARNUNG: Render-Pruefung nicht moeglich (in scripts/ "npm install" ausfuehren) - bitte im Browser ansehen";;
    *) echo "  Render-Pruefung FEHLGESCHLAGEN (Ausgabe: $BROWSER_LOG)"; sed 's/^/    /' "$BROWSER_LOG" | head -5
       return 1;;
  esac
}

echo "1/4 PHP-Syntaxpruefung"
ssh "$HOST" "docker exec -i $APP php -l" < "$LOCAL/extend.php" | grep -q "No syntax errors" \
  || { echo "ABBRUCH: extend.php hat Syntaxfehler. Es wurde NICHTS veraendert."; exit 1; }

echo "2/4 Sicherung: $BACKUP"
ssh "$HOST" "docker exec $APP cat /var/www/html/extend.php" > "$BACKUP"
[ -s "$BACKUP" ] || { echo "FEHLER: Sicherung leer, Abbruch"; exit 1; }

echo "3/4 Einspielen"
ssh "$HOST" "docker exec -u www-data $APP mkdir -p /var/www/html/freespawn-links"
put "$LOCAL/freespawn-links/forum.js" /var/www/html/freespawn-links/forum.js
put "$LOCAL/extend.php" /var/www/html/extend.php
clear_cache

echo "4/4 Pruefung"
sleep 3
if healthy; then echo "OK: Erweiterung ist live."; else
  echo "FEHLER nach dem Einspielen - Rollback der extend.php"
  put "$BACKUP" /var/www/html/extend.php; clear_cache; sleep 3
  curl -s -o /dev/null -w "  Startseite nach Rollback: HTTP %{http_code}\n" "$SITE/"
  exit 1
fi
