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
clear_cache() { ssh "$HOST" "docker exec -u www-data -w /var/www/html $APP php flarum cache:clear" >/dev/null; }
# Laufzeit-Pruefung im echten Browser (JS wird ausgefuehrt). Ein Fehler im Forum-JS liefert weiter HTTP 200,
# die Seite ist dann aber leer - genau das faengt nur diese Pruefung ab.
# Rueckgabe: 0 = rendert (3 Links + Suchfeld), 1 = kaputt, 2 = nicht pruefbar
rendered_ok() {
  command -v brave >/dev/null 2>&1 || return 2
  local dom
  # Desktop-Breite noetig: unter 992px zeigt Flarum das Suchfeld nur als Lupe (kein .Search-input).
  # Browser-Konsole wird mitgeschrieben (BROWSER_LOG), damit ein Fehlschlag diagnostizierbar ist.
  dom="$(timeout 150 brave --headless=new --disable-gpu --no-sandbox \
        --user-data-dir="${BRAVE_PROFILE:-$HOME/.cache/freespawn-deploy-browser}" \
        --window-size=1400,700 --virtual-time-budget=12000 --enable-logging=stderr --v=0 --dump-dom "$SITE/" 2>"$BROWSER_LOG" || true)"
  [ -n "$dom" ] || return 2
  # Here-Strings statt "printf | grep -q": unter pipefail meldet die Pipeline sonst einen Fehler (SIGPIPE), wenn
  # grep -q beim ersten Treffer aussteigt, obwohl gefunden wurde.
  local links; links="$(grep -o 'class="FreeSpawnLink"' <<<"$dom" | wc -l)"
  [ "$links" = 3 ] && grep -q 'class="Search-input"' <<<"$dom"
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
    0) echo "  Browser-Pruefung: Seite rendert (3 Links, Suchfeld)";;
    2) echo "  WARNUNG: Browser-Pruefung nicht moeglich (kein Brave / leere Ausgabe) - bitte im Browser ansehen";;
    *) echo "  Browser-Pruefung FEHLGESCHLAGEN: Seite rendert nicht (Konsole: $BROWSER_LOG)"
       grep -i -E "Uncaught|TypeError|ReferenceError|SyntaxError" "$BROWSER_LOG" | grep -v -i "extension-purpose" | cut -c1-300 | head -5 | sed 's/^/    /'
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
