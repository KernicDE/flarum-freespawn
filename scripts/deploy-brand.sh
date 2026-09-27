#!/usr/bin/env bash
# Spielt das FreeSpawn-Logo ins Forum ein (nach `python3 brand/build.py`):
#  - brand/dist/* -> public/brand/ im Forum-Container (+ public/favicon.ico),
#  - Pruefung, dass Favicon/Touch-Icon/Vorschaubild erreichbar UND im <head> verlinkt sind.
# Die Favicon/Touch-Icon/Vorschaubild-<link>/<meta>-Tags kommen NICHT aus diesem Skript,
# sondern aus local/extend.php (scripts/deploy-local-extension.sh) - Flarums Setting
# "custom_header" landet laut Flarum-Doku sichtbar am Seitenanfang im <body>, nicht im
# <head>, und iOS' "Zum Home-Bildschirm" liest apple-touch-icon nur aus <head>.
# local/extend.php muss also VOR oder zusammen mit diesem Skript deployt sein.
# Das Zeichen im Kopf der Seite kommt aus theme/custom.less (deploy-theme.sh).
# Aufruf: scripts/deploy-brand.sh
set -euo pipefail

HOST="nicolas@kernic.net"
SITE="https://freespawn.de"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$HERE/brand/dist/favicon.svg" ] || { echo "brand/dist fehlt - erst 'python3 brand/build.py' ausfuehren"; exit 1; }

healthy() {
  local code html head
  for path in / /tags /brand/favicon.svg /brand/favicon-32.png /brand/apple-touch-icon.png /brand/social-preview.png /favicon.ico; do
    code="$(curl -s -o /dev/null -w '%{http_code}' "$SITE$path")"; [ "$code" = 200 ] || { echo "  $path -> HTTP $code"; return 1; }
  done
  html="$(curl -s "$SITE/" | tr '\n' ' ')"
  head="$(grep -oP '(?s)<head>.*?</head>' <<<"$html" || true)"
  [ -n "$head" ] || { echo "  <head> nicht gefunden"; return 1; }
  grep -q 'rel="icon" type="image/svg+xml" href="/brand/favicon.svg' <<<"$head" || { echo "  Favicon-Link fehlt im <head>"; return 1; }
  grep -q 'rel="apple-touch-icon"' <<<"$head" || { echo "  apple-touch-icon fehlt im <head> (local/extend.php deployt? scripts/deploy-local-extension.sh)"; return 1; }
}

echo "1/2 Dateien nach public/brand/"
tar -C "$HERE/brand/dist" -cf - . | ssh "$HOST" "docker exec -i flarum-app-freespawn sh -c 'mkdir -p /var/www/html/public/brand && tar -xf - -C /var/www/html/public/brand && cp /var/www/html/public/brand/favicon.ico /var/www/html/public/favicon.ico && chown -R www-data:www-data /var/www/html/public/brand /var/www/html/public/favicon.ico'"

echo "2/2 Pruefung"
sleep 2
if healthy; then echo "OK: Favicon und Vorschaubild sind live (im <head>)."; else
  echo "FEHLER bei der Pruefung - siehe Ausgabe oben."
  exit 1
fi
