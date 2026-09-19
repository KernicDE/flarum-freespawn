# Forum-Theme (v9)

Das Theme liegt bei Flarum nicht im Repo, sondern als Setting `custom_less`
in der Datenbank. Diese Dateien sind die versionierte Quelle dazu.

| Datei | Zweck |
|---|---|
| `custom.less` | Theme v9. Inhalt gehört in `custom_less` |
| `fonts/inter-var.woff2` | Fließtext-Schrift Inter (variabel, Latin, OFL-Lizenz). Muss unter `public/fonts/` liegen |
| `custom.less.rollback-v8` | Vorheriges `custom_less` (v8), Stand 2026-09-19. Enthält nur noch die Variablen-Präfixe `@fs-` statt der alten; sonst unverändert |

Schriftarten von Chakra Petch liegen bereits auf dem Server. Rajdhani wird von v9
nicht mehr verwendet, die Dateien können dort bleiben.

## Einspielen

**Empfohlen: `scripts/deploy-theme.sh`.** Es sichert den Live-Wert, testet vorab mit less.php (dem Compiler
von Flarum, strenger als less.js), spielt ein, prüft Startseite/Themen/Diskussion/CSS und rollt bei einem
Fehler automatisch zurück. Hintergrund: Ein Fehler beim Kompilieren macht die Live-Seite kaputt (HTTP 500).
Bekannter Stolperstein: `calc()` mit Rechnen auf `var(...)` muss als `~"calc(...)"` maskiert werden.

Von Hand (ohne Sicherheitsnetz):

1. Schrift auf den Server legen (`public/fonts/` ist der Pfad, den nginx ausliefert):

   ```bash
   scp theme/fonts/inter-var.woff2 nicolas@kernic.net:/opt/docker/freespawn/flarum-freespawn/data/flarum/public/fonts/
   ```

2. Im Admin-Bereich unter **Aussehen → Eigenes CSS/LESS** den Inhalt von `custom.less`
   einfügen und speichern. Flarum kompiliert das CSS beim Speichern neu.

3. Seite mit Strg+Shift+R neu laden und prüfen: Header, Login-Modal,
   Diskussionsliste, Diskussionsseite, `/tags` und Handy-Ansicht.

## Rollback

Inhalt von `custom.less.rollback-v8` in **Aussehen → Eigenes CSS/LESS**
einfügen und speichern.

## Was geprüft wurde

- Kompiliert fehlerfrei mit less.js und less.php (Flarum 1.8.19). Beide Ausgaben sind identisch.
- Kontraste (WCAG): Text auf allen Flächen mindestens 5,4:1, Weiß im Header-Verlauf
  mindestens 4,9:1, Feldränder mindestens 3,3:1.
- Text ausschließlich in `rem`, keine px-Schriftgrößen.
- Sichtprüfung gegen die Live-CSS (Header, Hero, Liste, Login-Modal, Dropdown,
  Diskussion, Themen, Handy-Drawer).

## Grenzen

Reines CSS. Avatar-Stapel, Ansichtszähler oder Buttons im Hero brauchen Markup-Änderungen
und damit eine eigene Extension über `extend.php`.

## Kategorie-Farben (Tags)

Die Tag-Farben stehen in der Tabelle `tags` (nicht im LESS). Neue Palette: gleiche
Helligkeit (OKLCH L=0,55, Technik 0,50), Weiß darauf mindestens 4,59:1, je Farbfamilie
eine geplante Kategorie (Clan / Community / Gaming & Technik / Intern). Das Theme
erzwingt weißen Text auf Tag-Farben (`--contrast-color`), sonst wählt Flarum je nach
YIQ-Schwelle teils dunklen Text.

| id | Tag | alt | neu |
|---|---|---|---|
| 8 | News | `#D32F2F` | `#AD5437` |
| 4 | Bewerbungen | `#FBC02D` | `#9A6509` |
| 1 | Allgemein | `#888` | `#63728C` |
| 9 | Diskussion | `#96d35f` | `#6467B9` |
| 10 | Hilfe | `#00c7fc` | `#087AAF` |
| 5 | Gaming | `#388E3C` | `#4C8238` |
| 11 | Linux | `#fffc41` | `#118568` |
| 3 | Technik | `#7B1FA2` | `#007184` |
| 7 | Intern | `#E64A19` | `#8A5AA6` |
| 2 | Moderation | `#5D4037` | `#A05481` |

Zurück auf die alten Farben: dieselbe Tabelle mit vertauschten Spalten per
`UPDATE tags SET color='<alt>' WHERE id=<id>;` einspielen.

## Kategorie > Board > Thread (Stand 2026-09-19)

Struktur (Flarum-Tags: Kategorie = Eltern-Tag, Board = Kind-Tag), angelegt mit
`scripts/restructure-categories-20260919.sql`:

| Kategorie | Boards |
|---|---|
| Clan | News, Bewerbungen |
| Community | Allgemein, Diskussion, Hilfe |
| Gaming & Technik | Gaming, Technik, Linux |
| Interner Bereich | Intern, Moderation |

Kategorie-Farben (Eltern-Tags, jeweils Familie ihrer Boards): Clan `#A65C20`,
Community `#5171AC`, Gaming & Technik `#158561`, Interner Bereich `#945798`.

**Pflicht "genau eine Kategorie + genau ein Board":** Flarum zaehlt oberste Tags als
"primaer" und Kind-Tags als "sekundaer". Deshalb stehen in den Tag-Einstellungen
`flarum-tags.min/max_primary_tags = 1` (Kategorie) und `flarum-tags.min/max_secondary_tags = 1`
(Board). Der Tag-Dialog blendet Boards erst nach Wahl der Kategorie ein
(`requireParentTag`, in Flarum fest eingebaut). Admins koennen die Pflicht ueber den Schalter
"Anforderungen umgehen" (Recht `bypassTagCounts`) uebergehen; das laesst sich fuer Admins nicht abschalten.
Serverseitig prueft Flarum nur die Anzahl, nicht ob das Board zur gewaehlten Kategorie gehoert.

In der Diskussionsliste stehen Kategorie und Board als verbundene Pille (Kategorie
abgedunkelt, Board in voller Farbe) in der Meta-Zeile.

Umzug bestehender Threads: bisheriges Haupt-Tag blieb erhalten (News, Diskussion),
Gaming/Linux/Technik-Zweittags entfielen; unmarkierte Threads kamen nach Allgemein bzw. Hilfe.
