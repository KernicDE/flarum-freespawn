// Prueft im ausgefuehrten DOM (jsdom), dass das Forum rendert: 3 FreeSpawn-Links, Suchfeld, keine JS-Fehler.
// Ein Fehler im Forum-JS liefert weiter HTTP 200, die Seite ist dann aber leer.
// Aufruf: node check-render.js <URL>   (npm install im Ordner scripts/ noetig). Exit 0 = ok, 1 = kaputt.
const { JSDOM, VirtualConsole } = require('jsdom');
const util = require('util');

const errors = [];
const vc = new VirtualConsole();
vc.on('jsdomError', (e) => errors.push(String(e.message).slice(0, 200)));

// jsdom kennt einige Browser-APIs nicht, die Flarum 2 beim Start braucht.
function beforeParse(w) {
  w.TextEncoder = util.TextEncoder; w.TextDecoder = util.TextDecoder;
  w.matchMedia = () => ({ matches: false, media: '', addEventListener() {}, removeEventListener() {}, addListener() {}, removeListener() {} });
  w.XSLTProcessor = class { importStylesheet() {} setParameter() {} transformToFragment() { return w.document.createDocumentFragment(); } };
  w.ResizeObserver = class { observe() {} unobserve() {} disconnect() {} };
  w.IntersectionObserver = class { observe() {} unobserve() {} disconnect() {} };
  w.scrollTo = () => {};
}

JSDOM.fromURL(process.argv[2], { runScripts: 'dangerously', resources: 'usable', pretendToBeVisual: true, virtualConsole: vc, beforeParse })
  .then((dom) => setTimeout(() => {
    const d = dom.window.document;
    const links = d.querySelectorAll('.FreeSpawnLink').length;
    const search = d.querySelectorAll('.Search-input').length;
    console.log(`links=${links} search=${search} errors=${errors.length}`);
    errors.slice(0, 3).forEach((e) => console.log('  ' + e));
    process.exit(links === 3 && search > 0 && errors.length === 0 ? 0 : 1);
  }, 12000))
  .catch((e) => { console.log('FEHLER: ' + e.message); process.exit(1); });
