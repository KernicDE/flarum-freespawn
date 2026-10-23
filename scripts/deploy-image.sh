#!/usr/bin/env bash
# Rollt den Stand von main auf den Server aus: wartet auf den GitHub-Actions-Build (Image nach GHCR),
# gleicht compose.yaml und nginx/default.conf ab, zieht das Image, startet neu, prueft die Seite und
# rollt bei Fehlern auf das vorherige Image zurueck.
# Voraussetzung: alles committed und auf origin/main gepusht.
# Aufruf: scripts/deploy-image.sh
set -euo pipefail

HOST="nicolas@kernic.net"
DIR="/opt/docker/freespawn/flarum-freespawn"
SITE="https://freespawn.de"
IMG="ghcr.io/kernicde/freespawn-flarum"
REPO="KernicDE/flarum-freespawn"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"
STAMP="$(date +%Y%m%d-%H%M%S)"

[ -z "$(git status --porcelain)" ] || { echo "FEHLER: uncommittete Aenderungen"; exit 1; }
git fetch -q origin main
SHA="$(git rev-parse HEAD)"
[ "$SHA" = "$(git rev-parse origin/main)" ] || { echo "FEHLER: HEAD ist nicht auf origin/main gepusht"; exit 1; }

echo "1/5 GitHub-Actions-Build fuer ${SHA:0:7}"
RUN=""
for _ in $(seq 1 30); do
  RUN="$(gh run list --repo "$REPO" --workflow build.yml --commit "$SHA" --json databaseId -q '.[0].databaseId' 2>/dev/null || true)"
  [ -n "$RUN" ] && break; sleep 5
done
[ -n "$RUN" ] || { echo "FEHLER: kein Build-Lauf zu diesem Commit gefunden"; exit 1; }
gh run watch "$RUN" --repo "$REPO" --exit-status >/dev/null || { echo "FEHLER: Build fehlgeschlagen (gh run view $RUN --log-failed)"; exit 1; }

echo "2/5 Konfiguration abgleichen"
for f in compose.yaml nginx/default.conf; do
  if ! ssh "$HOST" "cat $DIR/$f" | cmp -s - "$f"; then
    ssh "$HOST" "cp $DIR/$f $DIR/$f.bak-$STAMP"
    scp -q "$f" "$HOST:$DIR/$f"; echo "  $f aktualisiert (Sicherung: $f.bak-$STAMP)"
  fi
done

healthy() {
  local p js
  for p in / /tags /d/13-willkommen-bei-freespawn; do
    [ "$(curl -s -o /dev/null -w '%{http_code}' "$SITE$p")" = 200 ] || { echo "  $p nicht 200"; return 1; }
  done
  js="$(curl -s "$SITE/" | grep -oE 'assets/forum\.js\?v=[a-z0-9]+' | head -1)"
  curl -s "$SITE/$js" | grep -q "freespawn-links" || { echo "  forum.js ohne freespawn-links"; return 1; }
}
remote() { ssh "$HOST" "cd $DIR && $1"; }

echo "3/5 Image ziehen"
OLD="$(remote "docker image inspect $IMG:latest --format '{{.Id}}' 2>/dev/null || true")"
remote "docker compose pull flarum scheduler worker" | tail -3

echo "4/5 Neustart"
remote "docker compose up -d" | tail -8
sleep 8

echo "5/5 Pruefung"
if healthy; then echo "OK: ${SHA:0:7} ist live."; else
  echo "FEHLER - Rollback auf das vorherige Image"
  [ -n "$OLD" ] && remote "docker tag $OLD $IMG:latest && docker compose up -d" | tail -3
  sleep 8; healthy && echo "Rollback erfolgreich." || echo "ACHTUNG: auch nach dem Rollback nicht gesund - manuell pruefen!"
  exit 1
fi
