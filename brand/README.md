# FreeSpawn-Logo

Zeichen: offener Ring, grosser Punkt in der Mitte, gleichseitiges gerundetes Dreieck in der Lücke (Spitze zeigt vom
Zentrum nach aussen, Schwerpunkt auf der inneren Ringlinie). Farben: Orange `#ff9a3d` → `#ff6d00`, Ring `#f4f4f8` (dunkler Grund)
bzw. `#15151d` (heller Grund), Schrift Chakra Petch (Free 500, Spawn 700).

- `build.py` erzeugt alles nach `dist/` (`python3 brand/build.py`; braucht fonttools, brotli, rsvg-convert, ImageMagick).
  Die Schrift ist als Pfade eingebettet, die SVGs brauchen keine Fonts.
- `dist/`: `mark-dark|light|header.svg` (nur Zeichen), `logo-dark|light.svg` (Zeichen + Schriftzug), `favicon.svg/.ico/-16|32|48.png`,
  `apple-touch-icon.png`, `icon-192|512.png`, `profile-1024.png` (Profilbild, quadratisch), `social-preview.svg/.png` (1200x630).
- Favicon hat einen dickeren Ring und etwas kleineren Punkt/Dreieck, damit bei 16 px alles getrennt bleibt.
- Einspielen ins Forum: `scripts/deploy-brand.sh` (Dateien nach `public/brand/`, Setting `custom_header` aus `custom_header.html`,
  Sicherung + Rollback), danach `scripts/deploy-theme.sh` fuer das Zeichen in der Kopfleiste (`#home-link::before`).
  Bei Aenderungen an den Dateien die `?v=1`-Version in `custom_header.html` und `theme/custom.less` hochzaehlen (nginx cached 1 Jahr).
- Mastodon (`../mastodon-freespawn/theme/`): `freespawn-icon.png` = `profile-1024.png`, `freespawn-thumbnail.png` = `social-preview.png`,
  hochgeladen als `SiteUpload` (favicon, app_icon, thumbnail); das Zeichen im CSS ist als data-URI eingebettet (dunkel und hell).
- Entwurfsphase (Varianten, Generator): `~/Development/freespawn/logo-konzepte/`.
