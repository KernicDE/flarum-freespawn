# Lokale Flarum-Erweiterung: Links in der Kopfleiste + Head-Tags

Diese kleine Erweiterung ohne Build-Schritt fügt links neben dem Titel Links zu **IRC**, **Mumble** und
**Mastodon** ein. Nur das Symbol ist sichtbar, der Text klappt bei Hover und Tastaturfokus aus (auf
Touch-Geräten und im Handy-Menü steht er immer daneben). Das Aussehen steht im Theme
(`theme/custom.less`, Klasse `.FreeSpawnLink`), die Links selbst in `freespawn-links/forum.js`.

Zusätzlich hängt `extend.php` über `Extend\Frontend::content()` die Favicon-/Touch-Icon-/Vorschaubild-Tags
in den echten `<head>` (siehe `brand/README.md`). **Nicht** über Flarums Setting `custom_header` machen:
das ist laut Flarum-Doku für sichtbaren Inhalt "am Seitenanfang" gedacht und landet im `<body>`. Browser
übernehmen ein `<link rel="icon">` dort trotzdem für den Tab, aber iOS' "Zum Home-Bildschirm" liest
`apple-touch-icon` nur aus `<head>` — genau das war der Bug, den dieser Ansatz behebt.

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
`freespawn-links/` nach `data/flarum/`, leert den Cache und prüft anschließend die Seite. Danach prüft es die Seite im ausgeführten DOM (jsdom, `scripts/check-render.js`, einmalig `npm install` in `scripts/`): 3 Links, Suchfeld und keine JS-Fehler. Bei einem
Fehler wird automatisch auf die alte `extend.php` zurückgerollt. Ohne `npm install` gibt es nur eine Warnung.

Neben den 3 Links hängt `forum.js` einen **Deck**-Link ins Benutzermenü und als Symbol oben rechts (nur für
eingeloggte Nutzer mit der Berechtigung `canUseDeck`).

## Stolpersteine (alle beim Bau gefunden)

- **`module.exports` ist Pflicht.** Flarum hängt hinter jede lokale JS-Datei
  `flarum.extensions['site-custom']=module.exports` an und liest beim Start daraus. Fehlt der Export
  (`module.exports = {}` am Dateiende), bricht die gesamte Forum-App mit
  `Cannot read properties of undefined (reading 'extend')` ab. HTTP bleibt dabei 200, die Seite ist aber leer.
- **Flarum 2:** Das alte `flarum.core.compat` gibt es nicht mehr. Die Module kommen aus der Export-Registry:
  `flarum.reg.get('core', 'common/extend')`, `'forum/components/HeaderPrimary'`, `'common/components/Icon'`
  (Icon ist eine Komponente: `m(Icon, { name: 'fas fa-hashtag' })`).
- Das Asset-Bundle enthält die Datei nur, wenn `extend.php` beim `cache:clear` aktiv war. Nach dem Einspielen
  immer `cache:clear` ausführen und PHP-FPM neu laden (macht das Deploy-Skript).
- Flarum führt die Extender aus `extend.php` **vor** allen Extensions aus. Für die Datei selbst ist die
  Reihenfolge im Bundle unkritisch.
- Ein Test gegen ein Wegwerf-Staging (Container mit Kopie der Dateien, `php -S`, SSH-Tunnel) ist gefahrlos
  möglich: Container aus dem Image `freespawn-flarum` mit gemountetem Dateikopie-Verzeichnis, `config.php`-`url`
  auf `http://localhost:<Port>`, Eigentümer auf `www-data` (82:82).
