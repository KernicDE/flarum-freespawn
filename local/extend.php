<?php

/*
 * Lokale Flarum-Erweiterungen fuer FreeSpawn. Diese Datei gehoert nach
 * <flarum-verzeichnis>/extend.php (auf dem Server: data/flarum/extend.php),
 * der Ordner freespawn-links/ daneben. Siehe local/README.md.
 */

use Flarum\Extend;
use Flarum\Frontend\Document;

return [
    // Links zu IRC, Mumble und Mastodon in der Kopfleiste (Stil: theme/custom.less)
    // + Favicon/Touch-Icon/Vorschaubild-Tags im echten <head>.
    //
    // Absichtlich NICHT ueber Flarums Setting "custom_header": das landet laut
    // Flarum-Doku sichtbar am Seitenanfang im <body>, nicht im <head>. Browser
    // uebernehmen ein <link rel="icon"> dort trotzdem fuer den Tab, aber iOS'
    // "Zum Home-Bildschirm" liest apple-touch-icon nur aus <head> - das Icon
    // fehlte deshalb beim Hinzufuegen zum Homescreen. Bei Aenderungen an den
    // Brand-Dateien die "?v=1"-Version hier UND in theme/custom.less hochzaehlen
    // (nginx cached 1 Jahr, siehe brand/README.md).
    (new Extend\Frontend('forum'))
        ->js(__DIR__.'/freespawn-links/forum.js')
        ->content(function (Document $document) {
            $document->head[] = <<<'HTML'
<link rel="icon" type="image/svg+xml" href="/brand/favicon.svg?v=1">
<link rel="icon" type="image/png" sizes="32x32" href="/brand/favicon-32.png?v=1">
<link rel="icon" type="image/png" sizes="16x16" href="/brand/favicon-16.png?v=1">
<link rel="apple-touch-icon" href="/brand/apple-touch-icon.png?v=1">
<meta property="og:image" content="https://freespawn.de/brand/social-preview.png?v=1">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
HTML;
        }),
];
