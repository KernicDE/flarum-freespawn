#!/usr/bin/env bash
# Spielt theme/custom.less als Setting `custom_less` auf den Server ein - sicher:
#  1. sichert den aktuellen Live-Wert lokal,
#  2. kompiliert mit less.php (dem Compiler von Flarum) und bricht bei JEDEM Fehler ab,
#  3. schreibt den Wert, leert den Cache,
#  4. prueft die Seite und rollt bei Fehlern automatisch auf die Sicherung zurueck.
# Aufruf: scripts/deploy-theme.sh [Backup-Verzeichnis]
set -euo pipefail

HOST="nicolas@kernic.net"
DIR="/opt/docker/freespawn/flarum-freespawn"
SITE="https://freespawn.de"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
LESS="$HERE/theme/custom.less"
BACKUPS="${1:-$HERE/../backups}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BACKUPS/custom_less.before-deploy-$STAMP.less"
mkdir -p "$BACKUPS"

sql_client() {  # SQL von stdin an die Forum-DB (utf8mb4)
  ssh "$HOST" "cd $DIR && set -a && . ./.env && set +a && docker exec -i flarum-mariadb-freespawn mariadb --default-character-set=utf8mb4 -uflarum -p\"\$MARIADB_PASSWORD\" flarum"
}
set_less() {    # $1 = Datei; Wert als Hex-Literal, keine Quoting-Probleme
  python3 -c "import sys;print(\"UPDATE settings SET value=CONVERT(0x%s USING utf8mb4) WHERE \`key\`='custom_less';\" % open(sys.argv[1],'rb').read().hex())" "$1" | sql_client
  ssh "$HOST" "docker exec -u www-data -w /var/www/html flarum-app-freespawn php flarum cache:clear" >/dev/null
}
healthy() {
  local code css
  for path in / /tags /d/13-willkommen-bei-freespawn; do
    code="$(curl -s -o /dev/null -w '%{http_code}' "$SITE$path")"; [ "$code" = 200 ] || { echo "  $path -> HTTP $code"; return 1; }
  done
  css="$(curl -s "$SITE/" | grep -o "$SITE/assets/forum.css?v=[a-z0-9]*" | head -1)"
  [ -n "$css" ] && [ "$(curl -s -o /dev/null -w '%{http_code}' "$css")" = 200 ] || { echo "  forum.css nicht abrufbar"; return 1; }
}

echo "1/4 Sicherung: $BACKUP"
ssh "$HOST" "cd $DIR && set -a && . ./.env && set +a && docker exec flarum-mariadb-freespawn mariadb --default-character-set=utf8mb4 -uflarum -p\"\$MARIADB_PASSWORD\" flarum --raw -N -B -e \"select value from settings where \\\`key\\\`='custom_less';\"" | head -c -1 > "$BACKUP"
[ -s "$BACKUP" ] || { echo "FEHLER: Sicherung leer, Abbruch"; exit 1; }

echo "2/4 Compiler-Test (less.php im Forum-Container, nur Lesen)"
{ printf '<?php\nrequire "/var/www/html/vendor/autoload.php";\n$less = <<<'"'"'LESSEOF'"'"'\n'; cat "$LESS"; printf '\nLESSEOF;\ntry { $p = new Less_Parser(["compress"=>false]); echo strlen($p->parse($less)->getCss()), " Byte CSS\\n"; } catch (Throwable $e) { fwrite(STDERR, "LESSPHP-FEHLER: ".$e->getMessage()."\\n"); exit(1); }\n'; } | ssh "$HOST" 'docker exec -i flarum-app-freespawn php' \
  || { echo "ABBRUCH: less.php kann das Theme nicht kompilieren. Es wurde NICHTS veraendert."; exit 1; }

echo "3/4 Einspielen"
set_less "$LESS"

echo "4/4 Pruefung"
sleep 2
if healthy; then echo "OK: Theme ist live."; else
  echo "FEHLER nach dem Einspielen - Rollback auf $BACKUP"
  set_less "$BACKUP"; sleep 2
  healthy && echo "Rollback erfolgreich, Seite wieder in Ordnung." || echo "ACHTUNG: auch nach dem Rollback nicht gesund - manuell pruefen!"
  exit 1
fi
