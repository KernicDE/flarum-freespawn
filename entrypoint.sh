#!/bin/sh
set -e

FLARUM_DIR="/var/www/html"

cd "$FLARUM_DIR"

# Erstinitialisierung: nur wenn vendor/ fehlt, Flarum-Projekt anlegen.
if [ ! -d "vendor" ]; then
    echo "[entrypoint] Initialisiere Flarum-Projekt in ${FLARUM_DIR}..."
    composer create-project --no-interaction --prefer-dist --no-dev flarum/flarum .
fi

# Extensions werden per composer.json im Volume verwaltet (nicht mehr hier).

# Berechtigungen für Webserver setzen
chown -R www-data:www-data "$FLARUM_DIR" 2>/dev/null || true

if [ ! -f "config.php" ]; then
    echo "[entrypoint] Flarum ist noch nicht installiert."
    echo "[entrypoint] Bitte Setup-Wizard unter https://freespawn.de abschließen."
fi

exec "$@"
