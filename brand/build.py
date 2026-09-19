#!/usr/bin/env python3
"""Erzeugt alle FreeSpawn-Logo-Dateien (SVG + PNG + ICO) in brand/dist/.

Zeichen: offener Ring, grosser Punkt in der Mitte, gleichseitiges gerundetes Dreieck in der Lücke
(Spitze zeigt vom Zentrum nach aussen, Schwerpunkt auf der inneren Ringlinie).
Schrift (Chakra Petch) wird als Pfade eingebettet, damit die SVGs ohne Font überall gleich aussehen.
Benötigt: fonttools + brotli, rsvg-convert, ImageMagick (für .ico).
"""
import math, os, subprocess, sys
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

HERE = os.path.dirname(os.path.abspath(__file__))
DIST = os.path.join(HERE, "dist")
FONTS = os.path.join(HERE, "fonts")
os.makedirs(DIST, exist_ok=True)

ORANGE_A, ORANGE_B = "#ff9a3d", "#ff6d00"
INK_DARK_BG, INK_LIGHT_BG = "#f4f4f8", "#15151d"
BG = "#0c0c11"
GAP_MID = -45.0   # Lücke oben rechts (Bildschirmkoordinaten, y nach unten)


def grad(gid):
    return (f'<linearGradient id="{gid}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{ORANGE_A}"/>'
            f'<stop offset="1" stop-color="{ORANGE_B}"/></linearGradient>')


def mark_geometry(stroke=11, r=34, gap=85.9, dot_r=15, side=30, rho=3.5, cx=48, cy=48):
    a = math.radians(GAP_MID + gap / 2); b = math.radians(GAP_MID - gap / 2 + 360)
    x1, y1 = cx + r * math.cos(a), cy + r * math.sin(a)
    x2, y2 = cx + r * math.cos(b), cy + r * math.sin(b)
    ring = f"M{x1:.2f} {y1:.2f}A{r} {r} 0 1 1 {x2:.2f} {y2:.2f}"
    u = (math.cos(math.radians(GAP_MID)), math.sin(math.radians(GAP_MID))); v = (-u[1], u[0])
    rc = r - stroke / 2                                    # Schwerpunkt auf der inneren Ringlinie
    h = side * math.sqrt(3) / 2
    centroid = (cx + u[0] * rc, cy + u[1] * rc)
    tip = (centroid[0] + u[0] * 2 * h / 3, centroid[1] + u[1] * 2 * h / 3)
    bc = (centroid[0] - u[0] * h / 3, centroid[1] - u[1] * h / 3)
    tri = [tip, (bc[0] + v[0] * side / 2, bc[1] + v[1] * side / 2), (bc[0] - v[0] * side / 2, bc[1] - v[1] * side / 2)]
    k = (h / 3 - rho) / (h / 3)                             # nach innen versetzen, Strich (round join) rundet die Ecken
    inner = [(centroid[0] + (p[0] - centroid[0]) * k, centroid[1] + (p[1] - centroid[1]) * k) for p in tri]
    pts = " ".join(f"{x:.2f},{y:.2f}" for x, y in inner)
    return dict(ring=ring, stroke=stroke, dot_r=dot_r, cx=cx, cy=cy, pts=pts, rho=rho)


def mark_body(g, ring_col, accent, tri_col=None):
    tri_col = tri_col or accent
    return (f'<path d="{g["ring"]}" fill="none" stroke="{ring_col}" stroke-width="{g["stroke"]}" stroke-linecap="round"/>'
            f'<circle cx="{g["cx"]}" cy="{g["cy"]}" r="{g["dot_r"]}" fill="{accent}"/>'
            f'<polygon points="{g["pts"]}" fill="{tri_col}" stroke="{tri_col}" stroke-width="{2 * g["rho"]}" stroke-linejoin="round"/>')


DEFAULT = mark_geometry()
# Favicon: dickerer Ring, etwas kleinerer Punkt/Dreieck, damit bei 16 px alles getrennt bleibt
FAV = mark_geometry(stroke=13, dot_r=16, side=28, rho=4)
MARK_BOX = "4 4 88 88"


def write(name, text):
    with open(os.path.join(DIST, name), "w", encoding="utf8") as f:
        f.write(text)


def svg(box, body, extra_defs="", w=None, h=None):
    size = f' width="{w}" height="{h}"' if w else ""
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{box}"{size}><defs>{extra_defs}</defs>{body}</svg>\n'


# ---------- Text als Pfade ----------
def text_path(font_file, text, size, x, baseline, fill):
    font = TTFont(os.path.join(FONTS, font_file)); gs = font.getGlyphSet(); cmap = font.getBestCmap()
    upm = font["head"].unitsPerEm; s = size / upm; cur = x; out = []
    for ch in text:
        gn = cmap[ord(ch)]
        pen = SVGPathPen(gs)
        gs[gn].draw(TransformPen(pen, (s, 0, 0, -s, cur, baseline)))
        d = pen.getCommands()
        if d: out.append(d)
        cur += gs[gn].width * s
    return f'<path d="{" ".join(out)}" fill="{fill}"/>', cur


def cap_height(font_file):
    f = TTFont(os.path.join(FONTS, font_file)); return f["OS/2"].sCapHeight / f["head"].unitsPerEm


def wordmark(x, cy, cap, free_col, spawn_col):
    """'Free' (500) + 'Spawn' (700) auf Höhe cy zentriert, Grossbuchstabenhöhe = cap."""
    size = cap / cap_height("chakra-petch-700.woff2")
    baseline = cy + cap / 2
    p1, x2 = text_path("chakra-petch-500.woff2", "Free", size, x, baseline, free_col)
    p2, x3 = text_path("chakra-petch-700.woff2", "Spawn", size, x2, baseline, spawn_col)
    return p1 + p2, x3


def main():
    # 1) Zeichen allein
    write("mark-dark.svg", svg(MARK_BOX, mark_body(DEFAULT, INK_DARK_BG, "url(#g)"), grad("g")))
    write("mark-light.svg", svg(MARK_BOX, mark_body(DEFAULT, INK_LIGHT_BG, "url(#g)"), grad("g")))
    # Kopfleiste (orangefarbener Verlauf): weisser Ring, helle Akzente
    write("mark-header.svg", svg(MARK_BOX, mark_body(DEFAULT, "#ffffff", "#ffe2c6")))

    # 2) Zeichen + Schriftzug, waagrecht
    cap = 34
    for name, ink, spawn, defs in (("logo-dark.svg", INK_DARK_BG, "url(#g)", grad("g")),
                                   ("logo-light.svg", INK_LIGHT_BG, "#e65c00", grad("g"))):
        body = mark_body(DEFAULT, ink, "url(#g)")
        text, xe = wordmark(100, 48, cap, ink, spawn)
        write(name, svg(f"4 4 {xe:.0f} 88", body + text, defs))

    # 3) Favicon (dunkles Quadrat mit runden Ecken)
    def icon(box_size, pad_scale, rx, bg=BG, geo=FAV):
        s = pad_scale
        body = (f'<rect width="96" height="96" rx="{rx}" fill="{bg}"/>' if bg else "") + \
               f'<g transform="translate(48 48) scale({s}) translate(-48 -48)">{mark_body(geo, INK_DARK_BG, "url(#g)")}</g>'
        return svg("0 0 96 96", body, grad("g"), box_size, box_size)
    write("favicon.svg", icon(None, 0.92, 22).replace(' width="None" height="None"', ""))
    write("_icon-square.svg", icon(None, 0.80, 0))                       # ohne Rundung: apple-touch, Profilbild
    write("_icon-app.svg", icon(None, 0.92, 22))

    for px, src in ((16, "favicon.svg"), (32, "favicon.svg"), (48, "favicon.svg"),
                    (180, "_icon-square.svg"), (192, "_icon-app.svg"), (512, "_icon-app.svg"), (1024, "_icon-square.svg")):
        out = {180: "apple-touch-icon.png", 192: "icon-192.png", 512: "icon-512.png", 1024: "profile-1024.png"}.get(px, f"favicon-{px}.png")
        subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px), os.path.join(DIST, src), "-o", os.path.join(DIST, out)], check=True)
    subprocess.run(["magick", os.path.join(DIST, "favicon-16.png"), os.path.join(DIST, "favicon-32.png"),
                    os.path.join(DIST, "favicon-48.png"), os.path.join(DIST, "favicon.ico")], check=True)
    for tmp in ("_icon-square.svg", "_icon-app.svg"):
        os.remove(os.path.join(DIST, tmp))

    # 4) Social-Vorschau 1200x630 (Mastodon-Servervorschau, Link-Vorschauen)
    W, H = 1200, 630
    mark_scale = 1.75
    parts = [f'<rect width="{W}" height="{H}" fill="#0c0c11"/>',
             '<linearGradient id="hb" x1="0" y1="0" x2="1" y2="0.3"><stop offset="0" stop-color="#c24a00"/><stop offset="0.55" stop-color="#a33d00"/><stop offset="1" stop-color="#6b2800"/></linearGradient>',
             f'<rect width="{W}" height="152" fill="url(#hb)"/><rect y="150" width="{W}" height="3" fill="#ff6d00"/>']
    mark_w = 80 * 0.62 * mark_scale
    text, xe = wordmark(0, 0, 66, "#ffffff", "#ffffff")
    total = mark_w + 26 + xe
    x0 = (W - total) / 2
    parts.append(f'<g transform="translate({x0:.1f} {76 - 44 * 0.62 * mark_scale:.1f}) scale({0.62 * mark_scale:.3f}) translate(-8.5 -4)">{mark_body(DEFAULT, "#ffffff", "#ffe2c6")}</g>')
    text, _ = wordmark(x0 + mark_w + 26, 76, 66, "#ffffff", "#ffffff")
    parts.append(text)
    tag, _ = text_path("inter-var.woff2", "Deutsche entspannte Gaming und Tech Community", 33, 0, 0, "#ffffff")
    # Tagline zentriert: Breite messen
    def line(txt, size, y, fill):
        t, xe_ = text_path("inter-var.woff2", txt, size, 0, y, fill)
        off = (W - xe_) / 2
        t, _ = text_path("inter-var.woff2", txt, size, off, y, fill)
        return t
    parts.append(line("Deutsche entspannte Gaming und Tech Community", 33, 335, "#ffffff"))
    parts.append(line("Mastodon  ·  Forum  ·  Mumble  ·  IRC", 33, 415, "#b9b9cc"))
    write("social-preview.svg", svg(f"0 0 {W} {H}", "".join(parts)))
    subprocess.run(["rsvg-convert", "-w", str(W), "-h", str(H), os.path.join(DIST, "social-preview.svg"),
                    "-o", os.path.join(DIST, "social-preview.png")], check=True)
    print("fertig:", ", ".join(sorted(os.listdir(DIST))))


if __name__ == "__main__":
    main()
