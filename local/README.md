# Lokale Flarum-Erweiterung: Links in der Kopfleiste

Diese kleine Erweiterung ohne Build-Schritt fügt links neben dem Titel Links zu **IRC**, **Mumble** und
**Mastodon** ein. Nur das Symbol ist sichtbar, der Text klappt bei Hover und Tastaturfokus aus (auf
Touch-Geräten und im Handy-Menü steht er immer daneben). Das Aussehen steht im Theme
(`theme/custom.less`, Klasse `.FreeSpawnLink`), die Links selbst in `freespawn-links/forum.js`.

| Link | Ziel |
|---|---|
| IRC | `https://web.libera.chat/#freespawn` (Webchat, neuer Tab) |
| Mumble | `/d/15-mumble-anleitung` (Adresse und Client-Download) |
| Mastodon | `https://social.freespawn.de` (neuer Tab, `rel="me"`) |

## Einspielen

```bash
scripts/deploy-local-extension.sh
```

Das Skript prüft die PHP-Syntax, sichert die aktuelle `extend.php`, schreibt `extend.php` und
`freespawn-links/` nach `data/flarum/`, leert den Cache und prüft anschließend die Seite. Es startet dazu einen
Browser und verlangt, dass die Seite **im ausgeführten DOM** wirklich rendert (3 Links, Suchfeld). Bei einem
Fehler wird automatisch auf die alte `extend.php` zurückgerollt. Ohne Brave im `PATH` gibt es nur eine Warnung
(Profil per `BRAVE_PROFILE` einstellbar).

## Stolpersteine (alle beim Bau gefunden)

- **`module.exports` ist Pflicht.** Flarum hängt hinter jede lokale JS-Datei
  `flarum.extensions['site-custom']=module.exports` an und liest beim Start daraus. Fehlt der Export
  (`module.exports = {}` am Dateiende), bricht die gesamte Forum-App mit
  `Cannot read properties of undefined (reading 'extend')` ab. HTTP bleibt dabei 200, die Seite ist aber leer.
- Die Module heißen im Forum-Bundle ohne Präfix: `compat['extend']`, `compat['components/HeaderPrimary']`,
  `compat['helpers/icon']`.
- Flarum führt die Extender aus `extend.php` **vor** allen Extensions aus. Für die Datei selbst ist die
  Reihenfolge im Bundle unkritisch.
- Ein Test gegen ein Wegwerf-Staging (Container mit Kopie der Dateien, `php -S`, SSH-Tunnel) ist gefahrlos
  möglich: Container aus dem Image `freespawn-flarum` mit gemountetem Dateikopie-Verzeichnis, `config.php`-`url`
  auf `http://localhost:<Port>`, Eigentümer auf `www-data` (82:82).
