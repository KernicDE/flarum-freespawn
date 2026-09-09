#!/bin/sh
set -e

FLARUM_DIR="/var/www/html"

cd "$FLARUM_DIR"

# Erstinitialisierung: nur wenn vendor/ fehlt, Flarum-Projekt anlegen.
if [ ! -d "vendor" ]; then
    echo "[entrypoint] Initialisiere Flarum-Projekt in ${FLARUM_DIR}..."
    composer create-project --no-interaction --prefer-dist --no-dev flarum/flarum .
fi

# Hilfsfunktion: Extension installieren, falls noch nicht aktiv.
# Hinweis: "composer show <pkg>" (ohne -a) prüft NUR lokal installierte/
# angeforderte Pakete, nicht das Packagist-Repository - damit würde jede
# noch nicht installierte Extension fälschlich als "nicht verfügbar" gemeldet.
# Daher wird require direkt versucht und bei Fehlschlag sauber zurückgerollt.
require_extension() {
    pkg="$1"
    if composer show --installed "$pkg" >/dev/null 2>&1; then
        echo "[entrypoint] Extension ${pkg} bereits installiert."
        return
    fi
    echo "[entrypoint] Installiere Extension ${pkg}..."
    if composer require --no-interaction --no-update "$pkg" 2>/dev/null \
        && composer update --no-interaction --with-dependencies "$pkg"; then
        echo "[entrypoint] Extension ${pkg} installiert."
    else
        echo "[entrypoint] Extension ${pkg} konnte nicht installiert werden - überspringe."
        composer remove --no-interaction --no-update "$pkg" >/dev/null 2>&1 || true
    fi
}

# Gewünschte Extensions
require_extension "flarum/tags"
require_extension "fof/polls"
require_extension "fof/moderator-notes"
require_extension "ianm/syndication"       # RSS/Atom-Feeds (fof/syndication existiert nicht mehr unter diesem Namen)
require_extension "fof/cookie-consent"     # Cookie-Consent-Banner
require_extension "ralkage/flarum-hcaptcha" # hCaptcha (ianm/hcaptcha existiert nicht)

# Berechtigungen für Webserver setzen
chown -R www-data:www-data "$FLARUM_DIR" 2>/dev/null || true

if [ ! -f "config.php" ]; then
    echo "[entrypoint] Flarum ist noch nicht installiert."
    echo "[entrypoint] Bitte Setup-Wizard unter https://dlivr.it abschließen."
fi

exec "$@"
