# Forum-Theme (v9)

Das Theme liegt bei Flarum nicht im Repo, sondern als Setting `custom_less`
in der Datenbank. Diese Dateien sind die versionierte Quelle dazu.

| Datei | Zweck |
|---|---|
| `custom.less` | Theme v9. Inhalt gehört in `custom_less` |
| `fonts/inter-var.woff2` | Fließtext-Schrift Inter (variabel, Latin, OFL-Lizenz). Muss unter `public/fonts/` liegen |
| `custom.less.rollback-20260919` | Byte-genaue Kopie des vorherigen `custom_less` (v8), Stand 2026-09-19 |

Schriftarten von Chakra Petch liegen bereits auf dem Server. Rajdhani wird von v9
nicht mehr verwendet, die Dateien können dort bleiben.

## Einspielen

1. Schrift auf den Server legen (`public/fonts/` ist der Pfad, den nginx ausliefert):

   ```bash
   scp theme/fonts/inter-var.woff2 nicolas@kernic.net:/opt/docker/dlivr-it/flarum-dlivr-it/data/flarum/public/fonts/
   ```

2. Im Admin-Bereich unter **Aussehen → Eigenes CSS/LESS** den Inhalt von `custom.less`
   einfügen und speichern. Flarum kompiliert das CSS beim Speichern neu.

3. Seite mit Strg+Shift+R neu laden und prüfen: Header, Login-Modal,
   Diskussionsliste, Diskussionsseite, `/tags` und Handy-Ansicht.

## Rollback

Inhalt von `custom.less.rollback-20260919` in **Aussehen → Eigenes CSS/LESS**
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
