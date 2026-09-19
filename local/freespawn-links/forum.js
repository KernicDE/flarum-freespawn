/*
 * FreeSpawn: Links zu IRC, Mumble und Mastodon in der Kopfleiste (links neben dem Titel).
 *
 * Kleine lokale Erweiterung ohne Build-Schritt: haengt sich per extend() an HeaderPrimary.
 * Aussehen steht im Theme (theme/custom.less, ".FreeSpawnLink"). Wird ueber local/extend.php
 * in den Forum-Bundle eingebunden (siehe local/README.md).
 *
 * Bewusst defensiv: fehlt eine Schnittstelle (z.B. nach einem Flarum-Update), passiert nichts,
 * statt das ganze Forum zu stoeren.
 */
(function () {
  'use strict';
  try {
    var compat = window.flarum && window.flarum.core && window.flarum.core.compat;
    if (!compat) return;
    // Der Forum-Bundle registriert die Module ohne "forum/"- bzw. "common/"-Praefix.
    var extendModule = compat['extend'] || compat['common/extend'];
    var HeaderPrimary = compat['components/HeaderPrimary'] || compat['forum/components/HeaderPrimary'];
    var icon = compat['helpers/icon'] || compat['common/helpers/icon'];
    if (!extendModule || !HeaderPrimary || !icon || !window.app || !window.m) return;

    var LINKS = [
      { id: 'freespawnIrc',      priority: 30, icon: 'fas fa-hashtag',  label: 'IRC',
        title: 'IRC-Chat #freespawn im Browser öffnen (Libera.Chat)',
        href: 'https://web.libera.chat/#freespawn', external: true },
      { id: 'freespawnMumble',   priority: 20, icon: 'fas fa-headset',  label: 'Mumble',
        title: 'Mumble-Sprachchat: Adresse freespawn.de, Anleitung im Forum',
        href: '/d/15-mumble-anleitung', external: false },
      { id: 'freespawnMastodon', priority: 10, icon: 'fab fa-mastodon', label: 'Mastodon',
        title: 'FreeSpawn auf Mastodon (social.freespawn.de)',
        href: 'https://social.freespawn.de', external: true, rel: 'me' }
    ];

    window.app.initializers.add('freespawn-links', function () {
      compat = window.flarum.core.compat;
      extendModule.extend(HeaderPrimary.prototype, 'items', function (items) {
        LINKS.forEach(function (l) {
          var attrs = { href: l.href, title: l.title, 'aria-label': l.title };
          if (l.external) { attrs.target = '_blank'; attrs.rel = (l.rel ? l.rel + ' ' : '') + 'noopener'; }
          items.add(l.id, window.m('a.FreeSpawnLink', attrs,
            [icon(l.icon), window.m('span.FreeSpawnLink-label', l.label)]), l.priority);
        });
      });
    });
  } catch (e) {
    if (window.console) console.warn('[freespawn-links] nicht geladen:', e);
  }
})();

// Flarum haengt hinter jede lokale JS-Datei "flarum.extensions['site-custom']=module.exports" an und liest
// beim Start daraus (wie bei den gebauten Extension-Bundles). Ohne diesen leeren Export bricht der Start
// der gesamten Forum-App mit "Cannot read properties of undefined (reading 'extend')" ab.
try { module.exports = {}; } catch (e) { /* kein Modul-Kontext (z.B. Test ausserhalb von Flarum) */ }
