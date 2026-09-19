#!/usr/bin/env python3
"""Twitch-Panel-Bilder (320 px breit) für Forum, IRC, Mumble und Mastodon -> brand/dist/twitch-panels/.

Nutzt die Helfer aus build.py (Schrift als Pfade, Farben). Aufruf: python3 brand/panels.py
"""
import os, subprocess
from fontTools.ttLib import TTFont
import build as B

OUT = os.path.join(B.DIST, "twitch-panels")
os.makedirs(OUT, exist_ok=True)
W = 320
PAD = 20

PANELS = [
    ("forum", "Forum", "Guides, Fragen und Gaming-Talk. Ohne Algorithmus, ohne Werbung.", "freespawn.de"),
    ("irc", "IRC", "Schneller Chat auf Libera.Chat, ganz ohne Discord. Auch direkt im Browser.", "#freespawn"),
    ("mumble", "Mumble", "Zusammen zocken und quatschen. Latenzarm, werbefrei und offen für alle.", "freespawn.de:64738"),
    ("mastodon", "Mastodon", "Neuigkeiten aus der Community im Fediverse. Anmeldung nach Freischaltung.", "social.freespawn.de"),
]


def advance(font_file, text, size):
    f = TTFont(os.path.join(B.FONTS, font_file)); gs = f.getGlyphSet(); cmap = f.getBestCmap()
    s = size / f["head"].unitsPerEm
    return sum(gs[cmap[ord(c)]].width for c in text) * s


def wrap(text, font_file, size, width):
    lines, cur = [], ""
    for word in text.split():
        trial = (cur + " " + word).strip()
        if cur and advance(font_file, trial, size) > width:
            lines.append(cur); cur = word
        else:
            cur = trial
    if cur: lines.append(cur)
    return lines


def icon(kind, x, y):
    """Weisses Symbol in einem 52x52-Feld an (x, y)."""
    if kind == "forum":
        return (f'<g transform="translate({x} {y})"><path d="M8 13a5 5 0 0 1 5-5h26a5 5 0 0 1 5 5v15a5 5 0 0 1-5 5H27l-9 8v-8h-5a5 5 0 0 1-5-5z" fill="#fff"/>'
                '<rect x="15" y="15" width="22" height="3.5" rx="1.75" fill="#a33d00"/><rect x="15" y="22" width="15" height="3.5" rx="1.75" fill="#a33d00"/></g>')
    if kind == "mumble":
        return (f'<g transform="translate({x} {y})" fill="none" stroke="#fff" stroke-linecap="round">'
                '<path d="M13 28v-4a13 13 0 0 1 26 0v4" stroke-width="4"/>'
                '<rect x="8" y="26" width="9" height="15" rx="3.5" fill="#fff" stroke="none"/><rect x="35" y="26" width="9" height="15" rx="3.5" fill="#fff" stroke="none"/>'
                '<path d="M39.5 41q0 6-9 6" stroke-width="3"/><circle cx="29.5" cy="47" r="2.2" fill="#fff" stroke="none"/></g>')
    glyph = "#" if kind == "irc" else "@"
    size = 44
    w = advance("chakra-petch-700.woff2", glyph, size)
    path, _ = B.text_path("chakra-petch-700.woff2", glyph, size, x + 26 - w / 2, y + 26 + B.cap_height("chakra-petch-700.woff2") * size / 2, "#fff")
    return path


def panel(kind, title, text, link):
    band = 84
    lines = wrap(text, "inter-var.woff2", 16, W - 2 * PAD)
    y_text = band + 34
    lh = 24
    y_pill = y_text + (len(lines) - 1) * lh + 26
    pill_h = 42
    H = y_pill + pill_h + 22
    parts = [f'<rect width="{W}" height="{H}" fill="#0c0c11"/>',
             '<linearGradient id="hb" x1="0" y1="0" x2="1" y2="0.3"><stop offset="0" stop-color="#c24a00"/><stop offset="0.55" stop-color="#a33d00"/><stop offset="1" stop-color="#6b2800"/></linearGradient>',
             f'<rect width="{W}" height="{band}" fill="url(#hb)"/><rect y="{band - 3}" width="{W}" height="3" fill="#ff6d00"/>',
             icon(kind, PAD - 4, (band - 3 - 52) / 2)]
    t, _ = B.text_path("chakra-petch-700.woff2", title, 34, PAD + 60, (band - 3) / 2 + B.cap_height("chakra-petch-700.woff2") * 34 / 2, "#ffffff")
    parts.append(t)
    # kleines Zeichen rechts in der Leiste
    parts.append(f'<g transform="translate({W - PAD - 34} {(band - 3 - 34) / 2}) scale({34 / 88}) translate(-4 -4)">{B.mark_body(B.DEFAULT, "#ffffff", "#ffe2c6")}</g>')
    for i, ln in enumerate(lines):
        t, _ = B.text_path("inter-var.woff2", ln, 16, PAD, y_text + i * lh, "#e8e8f0")
        parts.append(t)
    parts.append(f'<defs>{B.grad("pg")}</defs><rect x="{PAD}" y="{y_pill}" width="{W - 2 * PAD}" height="{pill_h}" rx="10" fill="url(#pg)"/>')
    lw = advance("chakra-petch-700.woff2", link, 19)
    t, _ = B.text_path("chakra-petch-700.woff2", link, 19, (W - lw) / 2, y_pill + pill_h / 2 + B.cap_height("chakra-petch-700.woff2") * 19 / 2, "#1a0c00")
    parts.append(t)
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}">{"".join(parts)}</svg>\n', H


def main():
    for kind, title, text, link in PANELS:
        svg, H = panel(kind, title, text, link)
        base = os.path.join(OUT, f"panel-{kind}")
        with open(base + ".svg", "w", encoding="utf8") as f:
            f.write(svg)
        subprocess.run(["rsvg-convert", "-w", str(W), base + ".svg", "-o", base + ".png"], check=True)
        print(f"panel-{kind}.png  {W}x{H}")


if __name__ == "__main__":
    main()
