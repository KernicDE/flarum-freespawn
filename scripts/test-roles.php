<?php
// Prueft die Rechte-Matrix (Gast, Nutzer, Mitglied, Moderator, Admin) gegen die echten Flarum-Richtlinien.
// Test-Nutzer leben nur im Speicher, es wird nichts gespeichert.
// Aufruf: ssh nicolas@kernic.net "docker exec -u www-data -i flarum-app-freespawn php" < scripts/test-roles.php
require '/var/www/html/vendor/autoload.php';
$site = \Flarum\Foundation\Site::fromPaths(['base'=>'/var/www/html','public'=>'/var/www/html/public','storage'=>'/var/www/html/storage']);
$app = $site->bootApp();
use Flarum\User\User; use Flarum\User\Guest; use Flarum\Group\Group; use Flarum\Tags\Tag; use Flarum\Discussion\Discussion;

$roles = ['Gast'=>null, 'Nutzer'=>[2,3], 'Mitglied'=>[2,3,14], 'Moderator'=>[2,3,4], 'Admin'=>[1,2,3]];
// Test-Nutzer: laedt die Rechte seiner Gruppen aus group_permission (nichts wird gespeichert)
class RoleUser extends User {
    public $gids = [];
    public function getPermissions() { return \Flarum\Group\Permission::whereIn('group_id', $this->gids)->pluck('permission')->all(); }
    public function isAdmin() { return in_array(1, $this->gids); }
    public function isGuest() { return false; }
    public function hasPermission($p) { return $this->isAdmin() || in_array($p, $this->getPermissions()); }
}
$mk = function($ids) { static $n = 99000; if ($ids === null) return new Guest;
    $u = new RoleUser; $u->id = ++$n; $u->gids = $ids; return $u; };
$users = []; foreach ($roles as $l=>$ids) $users[$l] = $mk($ids);

$tags = [12=>'Clan',13=>'Community',14=>'Gaming&Technik',4=>'  Bewerbungen',3=>'  Technik',15=>'InternerBereich',7=>'  Intern',2=>'  Moderation'];
printf("%-18s", "Tag: sehen / schreiben"); foreach ($roles as $l=>$_) printf("%-13s", $l); echo "\n";
foreach ($tags as $id=>$name) {
  $tag = Tag::find($id); printf("%-18s", $name);
  foreach ($users as $l=>$u) printf("%-13s", ($u->can('viewForum',$tag)?'sehen':'-') . '/' . ($u->can('startDiscussion',$tag)?'schr.':'-'));
  echo "\n";
}
echo "\nAntworten (discussion.reply) in Threads mit diesen Tags:\n";
$cases = ['Community/Diskussion'=>[13,9], 'Clan/Bewerbungen'=>[12,4], 'Interner Bereich/Intern'=>[15,7], 'Interner Bereich/Moderation'=>[15,2]];
printf("%-28s", ""); foreach ($roles as $l=>$_) printf("%-13s", $l); echo "\n";
foreach ($cases as $name=>$ids) {
  $d = new Discussion; $d->setRelation('tags', Tag::whereIn('id',$ids)->get());
  printf("%-28s", $name);
  foreach ($users as $l=>$u) printf("%-13s", $u->can('reply',$d) ? 'ja' : '-');
  echo "\n";
}
echo "\nModeration (discussion.hide / rename) in Intern und Moderation:\n";
foreach (['Interner Bereich/Intern'=>[15,7],'Interner Bereich/Moderation'=>[15,2]] as $name=>$ids) {
  $d = new Discussion; $d->setRelation('tags', Tag::whereIn('id',$ids)->get()); printf("%-28s", $name);
  foreach ($users as $l=>$u) printf("%-13s", ($u->can('hide',$d)?'hide':'-').'/'.($u->can('rename',$d)?'ren':'-'));
  echo "\n";
}
