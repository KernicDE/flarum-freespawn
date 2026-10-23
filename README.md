# flarum-freespawn

Flarum-2-Forum für [freespawn.de](https://freespawn.de): PHP 8.5-FPM, Nginx, MariaDB 12, Redis, Scheduler und Queue-Worker als Docker-Compose-Stack hinter Traefik.

## Aufbau
| Teil | Zweck |
|---|---|
| `Dockerfile`, `entrypoint.sh`, `php-prod.ini`, `fpm-pool.conf` | Image (PHP 8.5, phpredis, OPcache, FPM `static`) |
| `compose.yaml` | Stack: `mariadb`, `redis`, `flarum`, `scheduler`, `worker`, `nginx` |
| `nginx/default.conf` | Webserver-Konfiguration |
| `local/` | lokale Erweiterung (`extend.php`, `freespawn-links/forum.js`), siehe `local/README.md` |
| `theme/custom.less` | Theme (Setting `custom_less`), siehe `theme/README.md` |
| `brand/` | Logo und Brand-Dateien |
| `scripts/` | Deploy- und Setup-Skripte |

Flarum selbst (`vendor/`, `composer.json`, `config.php`) liegt auf dem Server im Volume `data/flarum` und wird dort per Composer verwaltet, nicht in diesem Repo.

## Änderungen ausrollen
| Änderung | Weg |
|---|---|
| Image, Compose, Nginx | committen, `git push` (GitHub Actions baut das Image nach `ghcr.io/kernicde/freespawn-flarum`), dann `scripts/deploy-image.sh` |
| `local/extend.php`, `forum.js` | `scripts/deploy-local-extension.sh` |
| Theme | `scripts/deploy-theme.sh` |
| Flarum und Erweiterungen | auf dem Server: `composer update`, `php flarum migrate`, `php flarum cache:clear`, danach PHP-FPM neu laden |

`deploy-image.sh` wartet auf den Build, gleicht `compose.yaml` und `nginx/default.conf` mit dem Server ab, zieht das Image, startet neu, prüft die Seite und rollt bei Fehlern auf das vorherige Image zurück. Watchtower aktualisiert die Flarum-Container bei einem neuen `latest` ebenfalls selbst.

## Betrieb
- **OPcache** läuft mit `validate_timestamps=0`: nach jedem Composer-Lauf oder Datei-Deploy PHP-FPM neu laden (`docker exec flarum-app-freespawn kill -USR2 1`) und den Worker neu starten (`docker restart flarum-worker-freespawn`). Die Deploy-Skripte tun das.
- **Redis** hält Cache, Sessions, Settings und Queue (`fof/redis`, Konfiguration in `local/extend.php`, Passwort `REDIS_PASSWORD` aus `.env`). Ohne Redis antwortet das Forum mit 500.
- **Settings und Cache:** Flarum 2 cached Settings in Redis. Nach direkten SQL-Änderungen `php flarum cache:clear` **zweimal** ausführen.
- **Scheduler und Worker** laufen als eigene Container (`scheduler`, `worker`, gleiches Image).
- **Backup vor größeren Änderungen:** `mariadb-dump --single-transaction --routines --events --all-databases` und ein Tarball von `data/db` und `data/flarum` (Verzeichnis `backup/`, nicht im Repo).
- Rollback auf das Flarum-1.x-Image: Tag `ghcr.io/kernicde/freespawn-flarum:rollback-pre-flarum2-20261023-123123` (nur lokal auf dem Server vorhanden) sowie der Restore aus dem Backup.

## Einrichtung
`.env.example` nach `.env` kopieren und Werte setzen.
