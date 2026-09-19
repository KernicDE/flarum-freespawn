#!/usr/bin/env bash
# Spielt das FreeSpawn-Logo ins Forum ein (nach `python3 brand/build.py`):
#  - brand/dist/* -> public/brand/ im Forum-Container (+ public/favicon.ico),
#  - Setting `custom_header` = brand/custom_header.html (Favicon-Links, Link-Vorschau-Bild),
#  - Pruefung; bei Fehlern Rollback des Settings auf den gesicherten Wert.
# Das Logo im Kopf der Seite kommt aus theme/custom.less (deploy-theme.sh).
# Aufruf: scripts/deploy-brand.sh [Backup-Verzeichnis]
set -euo pipefail

HOST="nicolas@kernic.net"
DIR="/opt/docker/freespawn/flarum-freespawn"
SITE="https://freespawn.de"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
BACKUPS="${1:-$HERE/../backups}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BACKUPS/custom_header.before-brand-$STAMP.html"
mkdir -p "$BACKUPS"
[ -f "$HERE/brand/dist/favicon.svg" ] || { echo "brand/dist fehlt - erst 'python3 brand/build.py' ausfuehren"; exit 1; }

sql_client() {
  ssh "$HOST" "cd $DIR && set -a && . ./.env && set +a && docker exec -i flarum-mariadb-freespawn mariadb --default-character-set=utf8mb4 -uflarum -p\"\$MARIADB_PASSWORD\" flarum"
}
set_header() {  # $1 = Datei (auch leer erlaubt)
  python3 -c "import sys;h=open(sys.argv[1],'rb').read().hex();print(\"REPLACE INTO settings (\`key\`, value) VALUES ('custom_header', %s);\" % (\"CONVERT(0x%s USING utf8mb4)\" % h if h else \"''\"))" "$1" | sql_client
  ssh "$HOST" "docker exec -u www-data -w /var/www/html flarum-app-freespawn php flarum cache:clear" >/dev/null
}
healthy() {
  local code html
  for path in / /tags /brand/favicon.svg /brand/favicon-32.png /brand/apple-touch-icon.png /brand/social-preview.png /favicon.ico; do
    code="$(curl -s -o /dev/null -w '%{http_code}' "$SITE$path")"; [ "$code" = 200 ] || { echo "  $path -> HTTP $code"; return 1; }
  done
  html="$(curl -s "$SITE/")"
  grep -q 'rel="icon" type="image/svg+xml" href="/brand/favicon.svg' <<<"$html" || { echo "  Favicon-Link fehlt im HTML"; return 1; }
}

echo "1/4 Sicherung custom_header: $BACKUP"
ssh "$HOST" "cd $DIR && set -a && . ./.env && set +a && docker exec flarum-mariadb-freespawn mariadb --default-character-set=utf8mb4 -uflarum -p\"\$MARIADB_PASSWORD\" flarum --raw -N -B -e \"select coalesce((select value from settings where \\\`key\\\`='custom_header'),'');\"" | head -c -1 > "$BACKUP" || true
touch "$BACKUP"

echo "2/4 Dateien nach public/brand/"
tar -C "$HERE/brand/dist" -cf - . | ssh "$HOST" "docker exec -i flarum-app-freespawn sh -c 'mkdir -p /var/www/html/public/brand && tar -xf - -C /var/www/html/public/brand && cp /var/www/html/public/brand/favicon.ico /var/www/html/public/favicon.ico && chown -R www-data:www-data /var/www/html/public/brand /var/www/html/public/favicon.ico'"

echo "3/4 custom_header setzen"
set_header "$HERE/brand/custom_header.html"

echo "4/4 Pruefung"
sleep 2
if healthy; then echo "OK: Favicon und Vorschaubild sind live."; else
  echo "FEHLER - Rollback von custom_header auf $BACKUP"
  set_header "$BACKUP"; sleep 2
  exit 1
fi
