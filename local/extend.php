<?php

/*
 * Lokale Flarum-Erweiterungen fuer FreeSpawn. Diese Datei gehoert nach
 * <flarum-verzeichnis>/extend.php (auf dem Server: data/flarum/extend.php),
 * der Ordner freespawn-links/ daneben. Siehe local/README.md.
 */

use Flarum\Extend;

return [
    // Links zu IRC, Mumble und Mastodon in der Kopfleiste (Stil: theme/custom.less)
    (new Extend\Frontend('forum'))
        ->js(__DIR__.'/freespawn-links/forum.js'),
];
