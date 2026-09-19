-- Kategorie > Board Umstrukturierung (2026-09-19)
-- Kategorien = Eltern-Tags (primaer), Boards = Kind-Tags (sekundaer). Jeder Thread: genau 1 Kategorie + 1 Board.
-- Bewusst NICHT enthalten: Aenderungen an Zugriffsrechten/Sichtbarkeit (is_restricted, group_permission).
START TRANSACTION;

-- 1. Kategorien anlegen
INSERT INTO tags (name, slug, description, color, icon, position, parent_id, is_restricted, is_hidden, discussion_count) VALUES
  ('Clan', 'clan', 'Ankündigungen und Bewerbungen', '#A65C20', 'fas fa-shield-alt', 0, NULL, 0, 0, 0),
  ('Community', 'community', 'Austausch, Fragen und Hilfe', '#5171AC', 'fas fa-comments', 1, NULL, 0, 0, 0),
  ('Gaming & Technik', 'gaming-technik', 'Spiele, Hardware und Linux', '#158561', 'fas fa-gamepad', 2, NULL, 0, 0, 0),
  ('Interner Bereich', 'interner-bereich', 'Clan-interne Themen und Moderation', '#945798', 'fas fa-lock', 3, NULL, 0, 0, 0);

SET @t_clan = (SELECT id FROM tags WHERE slug='clan');
SET @t_community = (SELECT id FROM tags WHERE slug='community');
SET @t_gaming_technik = (SELECT id FROM tags WHERE slug='gaming-technik');
SET @t_interner_bereich = (SELECT id FROM tags WHERE slug='interner-bereich');
SET @t_news = (SELECT id FROM tags WHERE slug='news');
SET @t_applications = (SELECT id FROM tags WHERE slug='applications');
SET @t_general = (SELECT id FROM tags WHERE slug='general');
SET @t_diskussion = (SELECT id FROM tags WHERE slug='diskussion');
SET @t_hilfe = (SELECT id FROM tags WHERE slug='hilfe');
SET @t_gaming = (SELECT id FROM tags WHERE slug='gaming');
SET @t_tech = (SELECT id FROM tags WHERE slug='tech');
SET @t_linux = (SELECT id FROM tags WHERE slug='linux');
SET @t_internal = (SELECT id FROM tags WHERE slug='internal');
SET @t_officers = (SELECT id FROM tags WHERE slug='officers');

-- 2. Boards den Kategorien zuordnen (Position innerhalb der Kategorie), Icons, fehlende Beschreibungen
UPDATE tags SET parent_id=@t_clan, position=0, icon='fas fa-bullhorn' WHERE id=@t_news;
UPDATE tags SET parent_id=@t_clan, position=1, icon='fas fa-user-plus', description='Bewirb dich für den Clan' WHERE id=@t_applications;
UPDATE tags SET parent_id=@t_community, position=0, icon='fas fa-comment' WHERE id=@t_general;
UPDATE tags SET parent_id=@t_community, position=1, icon='fas fa-comments', description='Diskussionen rund um Spiele, Technik und alles andere' WHERE id=@t_diskussion;
UPDATE tags SET parent_id=@t_community, position=2, icon='fas fa-life-ring', description='Fragen, Anleitungen und Support' WHERE id=@t_hilfe;
UPDATE tags SET parent_id=@t_gaming_technik, position=0, icon='fas fa-gamepad' WHERE id=@t_gaming;
UPDATE tags SET parent_id=@t_gaming_technik, position=1, icon='fas fa-microchip' WHERE id=@t_tech;
UPDATE tags SET parent_id=@t_gaming_technik, position=2, icon='fab fa-linux', description='Linux, Proton und Open Source' WHERE id=@t_linux;
UPDATE tags SET parent_id=@t_interner_bereich, position=0, icon='fas fa-lock' WHERE id=@t_internal;
UPDATE tags SET parent_id=@t_interner_bereich, position=1, icon='fas fa-user-shield' WHERE id=@t_officers;

-- 3. Bestehende Threads: genau eine Kategorie + ein Board (bisheriges Haupt-Tag bleibt, sonst nach Thema)
DELETE FROM discussion_tag WHERE discussion_id IN (13,14,15,16,17,18,19,20);
INSERT INTO discussion_tag (discussion_id, tag_id) VALUES
  (13, @t_clan), (13, @t_news),
  (14, @t_community), (14, @t_general),
  (15, @t_community), (15, @t_hilfe),
  (16, @t_community), (16, @t_hilfe),
  (17, @t_gaming_technik), (17, @t_gaming),
  (18, @t_clan), (18, @t_news),
  (19, @t_community), (19, @t_diskussion),
  (20, @t_community), (20, @t_diskussion);

-- 4. Zaehler und letzter Beitrag pro Tag neu berechnen
UPDATE tags t SET
  discussion_count = (SELECT COUNT(*) FROM discussion_tag dt JOIN discussions d ON d.id=dt.discussion_id
                      WHERE dt.tag_id=t.id AND d.is_private=0 AND d.hidden_at IS NULL),
  last_posted_discussion_id = (SELECT d.id FROM discussion_tag dt JOIN discussions d ON d.id=dt.discussion_id
                      WHERE dt.tag_id=t.id AND d.is_private=0 AND d.hidden_at IS NULL ORDER BY d.last_posted_at DESC LIMIT 1),
  last_posted_at = (SELECT d.last_posted_at FROM discussion_tag dt JOIN discussions d ON d.id=dt.discussion_id
                      WHERE dt.tag_id=t.id AND d.is_private=0 AND d.hidden_at IS NULL ORDER BY d.last_posted_at DESC LIMIT 1),
  last_posted_user_id = (SELECT d.last_posted_user_id FROM discussion_tag dt JOIN discussions d ON d.id=dt.discussion_id
                      WHERE dt.tag_id=t.id AND d.is_private=0 AND d.hidden_at IS NULL ORDER BY d.last_posted_at DESC LIMIT 1);

-- 5. Pflicht: genau 1 Kategorie (primaer) + genau 1 Board (sekundaer = Kind-Tags)
UPDATE settings SET value='1' WHERE `key` IN ('flarum-tags.min_primary_tags','flarum-tags.max_primary_tags','flarum-tags.min_secondary_tags','flarum-tags.max_secondary_tags');

COMMIT;

SELECT p.name AS kategorie, c.id, c.name AS board, c.discussion_count n FROM tags p JOIN tags c ON c.parent_id=p.id ORDER BY p.position, c.position;
