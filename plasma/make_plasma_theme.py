#!/usr/bin/env python3
"""Generates the "Schiefer" Plasma theme (Motif/CDE edges) as SVG frame pieces.

    python3 make_plasma_theme.py [target]     (default: ./schiefer)

Each frame (FrameSvg prefix) is described as a small pixel image (border c pixels, center
4 pixels) and cut into the nine pieces topleft ... bottomright. Colors use the Plasma color
classes (ColorScheme-*), so the theme follows the active color scheme. Margins
(hint-*-margin) are the ones from Breeze.
"""
import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "schiefer"))

sys.path.insert(0, os.path.join(os.path.dirname(HERE), "common"))
import schiefercolors  # noqa: E402  (Motif color formula, shared with Qt style, decoration and palettes)

# Edge colors after Motif: top = mix(surface, white, f_top), bottom = mix(surface, black, f_bottom),
# select (grooves, pressed) = mix(surface, black, 0.15). SVG cannot compute, so the color comes from
# the ColorScheme classes at runtime and the opacity of the white or black layer is fixed.
# In Motif the fractions depend on the surface brightness. Here they are exact for the main window
# of the "Schiefer" palette (190,194,211: 57 % / 45 %). The other light palettes (brightness
# 72-79 %) differ by at most 1 percentage point; for Basalt (31 %) the exact values would be
# 53 % / 54 %, so its edges are a little lighter than in the Qt style.
REF_BG = (190, 194, 211)
_TS, _BS, _SEL = schiefercolors.factors(REF_BG)
LIGHT = ("#ffffff", _TS)
DARK = ("#000000", _BS)
SELECT = ("#000000", _SEL)   # Motif select color: grooves, pressed buttons (exact in the medium branch)
OUTLINE = ("#000000", 0.62)

BG = "ColorScheme-Background"
VIEW = "ColorScheme-ViewBackground"
BUTTON = "ColorScheme-ButtonBackground"
HL = "ColorScheme-Highlight"
NEUTRAL = "ColorScheme-NeutralText"
TEXT = "ColorScheme-Text"

STYLE = """<style type="text/css" id="current-color-scheme">
.ColorScheme-Background { color:#bec2d3; }
.ColorScheme-ViewBackground { color:#e2e5ed; }
.ColorScheme-ButtonBackground { color:#bec2d3; }
.ColorScheme-Highlight { color:#60729e; }
.ColorScheme-NeutralText { color:#966400; }
.ColorScheme-Text { color:#000000; }
</style>"""

MID = 4  # width of the center pieces


# ---------------------------------------------------------------- Pixelmodell
# A pixel is a list of layers: ("class", class name, opacity) or ("rgb", color, opacity)

def cls(name, op=1.0):
    return ("class", name, op)


def rgb(spec):
    return ("rgb", spec[0], spec[1])


def bevel_side(x, y, W, H, d):
    """Motif bevel like Helper::renderBevel: True = light edge, False = shadow edge."""
    if y == d and x <= W - 1 - d:
        return True
    if x == d and y <= H - 1 - d:
        return True
    return False


def make_frame(c, pixel):
    """pixel(x, y, W, H, depth) -> layer list; returns a raster image of size (2c+MID)^2."""
    W = H = 2 * c + MID
    img = [[None] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            d = min(x, y, W - 1 - x, H - 1 - y)
            img[y][x] = pixel(x, y, W, H, d)
    return img


def bevel_pixel(width, edge=BG, fill=BG, sunken=False, fill_layers=(), outline=False, open_side=None,
                inner_ring=None):
    """Returns a pixel function for a bevel frame.
       outline: 1 px dark outline outside the bevel; open_side: 'bottom'/'top'/... for tabs;
       inner_ring: (depth, layer), for example a focus line."""
    off = 1 if outline else 0

    def px(x, y, W, H, d):
        # open side: act as if the rectangle continued there
        xx, yy, WW, HH = x, y, W, H
        if open_side == "bottom":
            HH = H + 16
        elif open_side == "top":
            yy, HH = y + 16, H + 16
        elif open_side == "right":
            WW = W + 16
        elif open_side == "left":
            xx, WW = x + 16, W + 16
        dd = min(xx, yy, WW - 1 - xx, HH - 1 - yy)
        if outline and dd == 0:
            return [cls(edge), rgb(OUTLINE)]
        if dd - off < width:
            light = bevel_side(xx - off, yy - off, WW - 2 * off, HH - 2 * off, dd - off)
            if sunken:
                light = not light
            return [cls(edge), rgb(LIGHT if light else DARK)]
        layers = [cls(fill)] + list(fill_layers)
        if inner_ring and dd == inner_ring[0]:
            layers = layers + [inner_ring[1]]
        return layers
    return px


def empty_pixel(x, y, W, H, d):
    return []


def ring_pixel(depth, layer):
    def px(x, y, W, H, d):
        return [layer] if d == depth else []
    return px


def fill_pixel(layers):
    def px(x, y, W, H, d):
        return list(layers)
    return px


def etched_line_pixel(where, inset):
    """Etched double line along one edge (headers and footers), ending `inset` pixels before the borders."""
    def px(x, y, W, H, d):
        if where == "bottom":
            if x < inset or x > W - 1 - inset:
                return []
            if y == H - 2:
                return [rgb(DARK)]
            if y == H - 1:
                return [rgb(LIGHT)]
        if where == "top":
            if x < inset or x > W - 1 - inset:
                return []
            if y == 0:
                return [rgb(DARK)]
            if y == 1:
                return [rgb(LIGHT)]
        return []
    return px


# ---------------------------------------------------------------- SVG output

class Sheet:
    def __init__(self):
        self.parts = []
        self.y = 0
        self.width = 10

    def _layers_svg(self, x, y, w, h, layers):
        out = []
        for kind, val, op in layers:
            o = "" if op >= 1 else f' fill-opacity="{op:g}"'
            if kind == "class":
                out.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" class="{val}" style="fill:currentColor"{o}/>')
            else:
                out.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{val}"{o}/>')
        return out

    def _piece(self, eid, img, x0, y0, x1, y1, ox, oy):
        """Image region [x0,x1)x[y0,y1) as a group with id at position (ox, oy)."""
        body = [f'<rect x="{ox}" y="{oy}" width="{x1 - x0}" height="{y1 - y0}" fill="#000000" fill-opacity="0"/>']
        # Horizontal runs per row, then merge equal runs vertically. Single 1 px rectangles
        # leave semi-transparent seams when stretched.
        runs = []
        for y in range(y0, y1):
            x = x0
            while x < x1:
                spec = img[y][x]
                run = 1
                while x + run < x1 and img[y][x + run] == spec:
                    run += 1
                runs.append([x, y, run, 1, spec])
                x += run
        merged = []
        for r in runs:
            for m in merged:
                if m[0] == r[0] and m[2] == r[2] and m[4] == r[4] and m[1] + m[3] == r[1]:
                    m[3] += 1
                    break
            else:
                merged.append(r)
        for x, y, w, h, spec in merged:
            if spec:
                body += self._layers_svg(ox + x - x0, oy + y - y0, w, h, spec)
        self.parts.append(f'<g id="{eid}">' + "".join(body) + "</g>")

    def frame(self, prefix, c, pixel, margins=None, stretch=True):
        """Nine pieces of a frame; margins = (left, top, right, bottom) or None."""
        img = make_frame(c, pixel)
        p = (prefix + "-") if prefix else ""
        n = 2 * c + MID
        ox, oy = 0, self.y
        cuts = {"topleft": (0, 0, c, c), "top": (c, 0, c + MID, c), "topright": (c + MID, 0, n, c),
                "left": (0, c, c, c + MID), "center": (c, c, c + MID, c + MID), "right": (c + MID, c, n, c + MID),
                "bottomleft": (0, c + MID, c, n), "bottom": (c, c + MID, c + MID, n),
                "bottomright": (c + MID, c + MID, n, n)}
        gap = 2
        positions = {"topleft": (0, 0), "top": (1, 0), "topright": (2, 0), "left": (0, 1), "center": (1, 1),
                     "right": (2, 1), "bottomleft": (0, 2), "bottom": (1, 2), "bottomright": (2, 2)}
        cell = max(c, MID) + gap
        for name, (x0, y0, x1, y1) in cuts.items():
            gx, gy = positions[name]
            self._piece(p + name, img, x0, y0, x1, y1, ox + gx * cell, oy + gy * cell)
        hx = ox + 3 * cell + 4
        if margins is not None:
            ml, mt, mr, mb = margins
            hints = [("hint-left-margin", ml, 1), ("hint-top-margin", 1, mt),
                     ("hint-right-margin", mr, 1), ("hint-bottom-margin", 1, mb)]
            for i, (name, w, h) in enumerate(hints):
                self.parts.append(f'<rect id="{p}{name}" x="{hx + i * 20}" y="{oy}" width="{w}" height="{h}" '
                                  f'fill="#000000" fill-opacity="0"/>')
        if stretch:
            self.parts.append(f'<rect id="{p}hint-stretch-borders" x="{hx + 90}" y="{oy}" width="1" height="1" '
                              f'fill="#000000" fill-opacity="0"/>')
        self.width = max(self.width, hx + 120)
        self.y += 3 * cell + 8

    def element(self, eid, w, h, pixel_fn):
        """Single element (no frame), pixel_fn(x, y, w, h) -> layers."""
        img = [[pixel_fn(x, y, w, h) for x in range(w)] for y in range(h)]
        self._piece(eid, img, 0, 0, w, h, 0, self.y)
        self.width = max(self.width, w + 4)
        self.y += h + 6

    def raw(self, eid, w, h, inner):
        """Free SVG element (coordinates 0..w/0..h), for example circles."""
        self.parts.append(f'<g id="{eid}" transform="translate(0,{self.y})">'
                          f'<rect x="0" y="0" width="{w}" height="{h}" fill="#000000" fill-opacity="0"/>{inner}</g>')
        self.width = max(self.width, w + 4)
        self.y += h + 6

    def marker(self, eid, w=1, h=1):
        self.parts.append(f'<rect id="{eid}" x="{self.width + 10}" y="{self.y}" width="{w}" height="{h}" '
                          f'fill="#000000" fill-opacity="0"/>')
        self.y += h + 4

    def save(self, path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.width + 40}" height="{self.y + 10}">\n')
            f.write("<!-- Schiefer: generated by make_plasma_theme.py, do not edit -->\n")
            f.write(STYLE + "\n")
            f.write("\n".join(self.parts))
            f.write("\n</svg>\n")


# ---------------------------------------------------------------- Theme files

def raised(width=2, **kw):
    return bevel_pixel(width, **kw)


def sunken(width=2, **kw):
    return bevel_pixel(width, sunken=True, **kw)


HOVER_TINT = rgb(("#ffffff", 0.14))
PRESS_TINT = rgb(SELECT)


def popup_background(margins):
    s = Sheet()
    s.frame("", 3, raised(2, outline=True), margins)
    return s


def build(dest):
    files = {}

    # Panel: raised surface (CDE front panel)
    s = Sheet()
    s.frame("", 2, raised(2), (4, 4, 4, 4))
    files["widgets/panel-background"] = s

    # Popups, menus, plasmoid backgrounds
    files["dialogs/background"] = popup_background((6, 6, 6, 6))
    files["widgets/background"] = popup_background((14, 14, 14, 14))
    files["widgets/translucentbackground"] = popup_background((14, 14, 14, 14))

    # Tooltip: plain with a dark outline (color = tooltip color group)
    s = Sheet()
    s.frame("", 1, bevel_pixel(0, outline=True), (4, 4, 4, 4))
    files["widgets/tooltip"] = s

    # Taskleiste
    s = Sheet()
    m = (5, 4, 5, 4)
    s.frame("normal", 2, raised(2), m)
    s.frame("normal-hover", 2, raised(2, fill_layers=[HOVER_TINT]), m)
    s.frame("hover", 2, raised(2, fill_layers=[HOVER_TINT]), m)
    s.frame("launcher-hover", 2, raised(2, fill_layers=[HOVER_TINT]), m)
    s.frame("focus", 2, sunken(2, fill_layers=[rgb(SELECT)]), m)
    s.frame("focus-hover", 2, sunken(2, fill_layers=[rgb(("#000000", 0.04))]), m)
    s.frame("minimized", 2, raised(1, fill_layers=[rgb(("#000000", 0.05))]), m)
    s.frame("minimized-hover", 2, raised(2, fill_layers=[HOVER_TINT]), m)
    s.frame("attention", 2, raised(2, fill_layers=[cls(NEUTRAL, 0.35)]), m)
    s.frame("attention-hover", 2, raised(2, fill_layers=[cls(NEUTRAL, 0.45)]), m)
    s.frame("progress", 2, lambda x, y, W, H, d: [] if d < 2 else [cls(HL, 0.45)], m)
    files["widgets/tasks"] = s

    # Buttons: focus = Motif highlight ring outside the button
    s = Sheet()
    s.frame("normal", 2, raised(2, edge=BG, fill=BUTTON), (6, 6, 6, 6))
    s.frame("pressed", 2, sunken(2, edge=BG, fill=BUTTON, fill_layers=[PRESS_TINT]), (6, 6, 6, 6))
    s.frame("hover", 2, lambda x, y, W, H, d: [] if d < 2 else [HOVER_TINT], (0.001, 0.001, 0.001, 0.001))
    s.frame("focus", 2, ring_pixel(0, cls(HL)), (2, 2, 2, 2))
    s.frame("toolbutton-hover", 2, raised(2, edge=BG, fill=BUTTON, fill_layers=[HOVER_TINT]), (4, 4, 4, 4))
    s.frame("toolbutton-pressed", 2, sunken(2, edge=BG, fill=BUTTON, fill_layers=[PRESS_TINT]), (4, 4, 4, 4))
    s.frame("toolbutton-focus", 2, ring_pixel(0, cls(HL)), (2, 2, 2, 2))
    files["widgets/button"] = s

    # Input fields: sunken, focus as an inner line
    s = Sheet()
    s.frame("base", 2, sunken(2, edge=BG, fill=VIEW), (6, 6, 6, 6))
    s.frame("hover", 3, empty_pixel, (0.001, 0.001, 0.001, 0.001))
    s.frame("focus", 3, ring_pixel(2, cls(HL)), (0.001, 0.001, 0.001, 0.001))
    s.marker("hint-focus-over-base")
    files["widgets/lineedit"] = s

    # Frames
    s = Sheet()
    s.frame("plain", 2, lambda x, y, W, H, d: [cls(BG)], (6, 6, 6, 6))
    s.frame("raised", 2, raised(2), (6, 6, 6, 8))
    s.frame("sunken", 2, sunken(2), (6, 6, 6, 6))
    files["widgets/frame"] = s

    # List items in popups (Kickoff, system tray ...): raised on hover like Qt menus
    s = Sheet()
    s.frame("normal", 2, empty_pixel, (6, 6, 6, 6))
    s.frame("hover", 2, raised(2), (6, 6, 6, 6))
    s.frame("pressed", 2, raised(2, fill=HL), (6, 6, 6, 6))
    s.frame("section", 2, etched_line_pixel("bottom", 0), (6, 6, 6, 6))
    s.element("separator", 8, 2, lambda x, y, w, h: [rgb(DARK)] if y == 0 else [rgb(LIGHT)])
    files["widgets/listitem"] = s

    s = Sheet()
    s.frame("normal", 2, empty_pixel, (5, 5, 5, 5))
    s.frame("hover", 2, raised(2), (5, 5, 5, 5))
    s.frame("selected", 2, raised(1, fill=HL), (5, 5, 5, 5))
    s.frame("selected+hover", 2, raised(2, fill=HL), (5, 5, 5, 5))
    files["widgets/viewitem"] = s

    s = Sheet()
    s.frame("normal", 2, empty_pixel, (8, 8, 8, 8))
    s.frame("hover", 2, raised(2), (8, 8, 8, 8))
    s.frame("pressed", 2, sunken(2), (8, 8, 8, 8))
    files["widgets/menubaritem"] = s

    # Popup headers and footers: only an etched line, ending before the popup bevel
    s = Sheet()
    s.frame("header", 6, etched_line_pixel("bottom", 3), None)
    s.frame("footer", 6, etched_line_pixel("top", 3), None)
    for i, (n, w, h) in enumerate([("hint-left-margin", 6, 1), ("hint-top-margin", 1, 4),
                                   ("hint-right-margin", 6, 1), ("hint-bottom-margin", 1, 4)]):
        s.parts.append(f'<rect id="{n}" x="{200 + i * 20}" y="0" width="{w}" height="{h}" fill="#000000" fill-opacity="0"/>')
    files["widgets/plasmoidheading"] = s

    # Tabs: three raised edges
    s = Sheet()
    s.frame("north-active-tab", 2, raised(2, open_side="bottom"), (6, 10, 6, 10))
    s.frame("south-active-tab", 2, raised(2, open_side="top"), (6, 10, 6, 10))
    s.frame("west-active-tab", 2, raised(2, open_side="right"), (4, 6, 8, 6))
    s.frame("east-active-tab", 2, raised(2, open_side="left"), (8, 6, 4, 6))
    files["widgets/tabbar"] = s

    # Scroll bar: sunken groove, raised slider
    s = Sheet()
    trough = sunken(2, fill=BG, fill_layers=[rgb(SELECT)])
    s.frame("background-vertical", 2, trough, None)
    s.frame("background-horizontal", 2, trough, None)
    s.frame("slider", 2, raised(2, fill=BUTTON), None)
    s.frame("mouseover-slider", 2, raised(2, fill=BUTTON, fill_layers=[HOVER_TINT]), None)
    for pre in ("slider", "mouseover-slider"):
        for side in ("left", "top", "right", "bottom"):
            s.parts.append(f'<rect id="{pre}-hint-{side}-inset" x="300" y="0" width="2" height="2" fill="#000000" fill-opacity="0"/>')
    s.parts.append('<rect id="hint-scrollbar-size" x="320" y="0" width="14" height="14" fill="#000000" fill-opacity="0"/>')
    files["widgets/scrollbar"] = s

    # Slider: sunken groove, fill, raised handle with a center groove
    s = Sheet()
    s.frame("groove", 4, sunken(2, fill=BG, fill_layers=[rgb(SELECT)]), None)
    s.frame("groove-highlight", 4, sunken(2, fill=HL), None)

    def thumb(horizontal, extra=()):
        def px(x, y, w, h):
            d = min(x, y, w - 1 - x, h - 1 - y)
            if d < 2:
                return [cls(BG), rgb(LIGHT if bevel_side(x, y, w, h, d) else DARK)]
            mid = (w // 2) if horizontal else (h // 2)
            pos = x if horizontal else y
            if pos == mid - 1:
                return [cls(BUTTON), rgb(DARK)]
            if pos == mid:
                return [cls(BUTTON), rgb(LIGHT)]
            return [cls(BUTTON)] + list(extra)
        return px

    s.element("horizontal-slider-handle", 20, 20, thumb(True))
    s.element("vertical-slider-handle", 20, 20, thumb(False))
    s.element("horizontal-slider-hover", 20, 20, lambda x, y, w, h: [HOVER_TINT] if min(x, y, w - 1 - x, h - 1 - y) >= 2 else [])
    s.element("vertical-slider-hover", 20, 20, lambda x, y, w, h: [HOVER_TINT] if min(x, y, w - 1 - x, h - 1 - y) >= 2 else [])
    ring = lambda x, y, w, h: [cls(HL)] if min(x, y, w - 1 - x, h - 1 - y) == 2 else []
    s.element("horizontal-slider-focus", 20, 20, ring)
    s.element("vertical-slider-focus", 20, 20, ring)
    s.element("horizontal-slider-shadow", 20, 20, lambda *a: [])
    s.element("vertical-slider-shadow", 20, 20, lambda *a: [])
    s.marker("hint-handle-size", 20, 20)
    files["widgets/slider"] = s

    # Radio button: sunken circle (like the Qt style), dot in the highlight color
    import math

    def arc(cx, cy, r, a0, a1, color, op, width=2):
        p0 = (cx + r * math.cos(math.radians(a0)), cy - r * math.sin(math.radians(a0)))
        p1 = (cx + r * math.cos(math.radians(a1)), cy - r * math.sin(math.radians(a1)))
        return (f'<path d="M {p0[0]:.3f} {p0[1]:.3f} A {r} {r} 0 0 0 {p1[0]:.3f} {p1[1]:.3f}" fill="none" '
                f'stroke="{color}" stroke-opacity="{op}" stroke-width="{width}"/>')

    s = Sheet()
    disc = (f'<circle cx="8" cy="8" r="7" class="{VIEW}" style="fill:currentColor"/>'
            + arc(8, 8, 6, 45, 225, DARK[0], DARK[1]) + arc(8, 8, 6, 225, 405, LIGHT[0], LIGHT[1]))
    s.raw("normal", 16, 16, disc)
    s.raw("hover", 16, 16, f'<circle cx="8" cy="8" r="4.5" fill="#ffffff" fill-opacity="0.15"/>')
    s.raw("checked", 16, 16, "")
    s.raw("symbol", 8, 8, f'<circle cx="4" cy="4" r="4" class="{HL}" style="fill:currentColor"/>')
    s.raw("focus", 20, 20, f'<circle cx="10" cy="10" r="9.5" fill="none" class="{HL}" style="stroke:currentColor" stroke-width="1"/>')
    s.raw("shadow", 22, 22, "")
    s.marker("hint-size", 16, 16)
    files["widgets/radiobutton"] = s

    # Switch: sunken groove (off: gray, on: highlight), raised square handle
    s = Sheet()
    def bar(prefix, fill_layers):
        img = make_frame(6, sunken(2, fill=BG, fill_layers=fill_layers))   # 16 px high like the handle
        n = len(img)
        s._piece(prefix + "-left", img, 0, 0, 6, n, 0, s.y)
        s._piece(prefix + "-center", img, 6, 0, 6 + MID, n, 10, s.y)
        s._piece(prefix + "-right", img, 6 + MID, 0, n, n, 20, s.y)
        s.y += n + 6
    bar("inactive", [rgb(SELECT)])
    bar("active", [cls(HL, 0.85)])

    def knob(extra=()):
        def px(x, y, w, h):
            d = min(x, y, w - 1 - x, h - 1 - y)
            if d < 2:
                return [cls(BG), rgb(LIGHT if bevel_side(x, y, w, h, d) else DARK)]
            return [cls(BUTTON)] + list(extra)
        return px
    s.element("handle", 16, 16, knob())
    s.element("handle-hover", 16, 16, lambda x, y, w, h: [HOVER_TINT] if min(x, y, w - 1 - x, h - 1 - y) >= 2 else [])
    s.element("handle-pressed", 16, 16, lambda x, y, w, h: ([cls(BG), rgb(DARK if bevel_side(x, y, w, h, min(x, y, w - 1 - x, h - 1 - y)) else LIGHT)]
                                                          if min(x, y, w - 1 - x, h - 1 - y) < 2 else [cls(BUTTON), PRESS_TINT]))
    s.element("handle-focus", 20, 20, lambda x, y, w, h: [cls(HL)] if min(x, y, w - 1 - x, h - 1 - y) == 0 else [])
    s.element("handle-shadow", 16, 16, lambda *a: [])
    s.marker("hint-bar-size", 34, 16)
    s.marker("hint-stretch-borders")
    files["widgets/switch"] = s

    # Trennlinien
    s = Sheet()
    s.element("horizontal-line", 16, 2, lambda x, y, w, h: [rgb(DARK)] if y == 0 else [rgb(LIGHT)])
    s.element("vertical-line", 2, 16, lambda x, y, w, h: [rgb(DARK)] if x == 0 else [rgb(LIGHT)])
    files["widgets/line"] = s

    # ---- write
    if os.path.isdir(dest) and os.path.exists(os.path.join(dest, ".schiefer-generated")):
        shutil.rmtree(dest)
    os.makedirs(dest, exist_ok=True)
    open(os.path.join(dest, ".schiefer-generated"), "w").close()
    for rel, sheet in files.items():
        sheet.save(os.path.join(dest, rel + ".svg"))
    # Translucent variants: the same opaque files, so nothing falls back to Breeze
    for variant in ("solid", "translucent", "opaque"):
        for rel in ("dialogs/background", "widgets/panel-background", "widgets/tooltip",
                    "widgets/background"):
            if rel in files:
                files[rel].save(os.path.join(dest, variant, rel + ".svg"))

    meta = {
        "KPlugin": {
            "Authors": [{"Name": "Schiefer"}],
            "Category": "",
            "Description": "Motif/CDE-like edges based on the Breeze spacing",
            "Description[de]": "Motif/CDE-artige Kanten auf Basis der Breeze-Abstände",
            "EnabledByDefault": True,
            "Id": "schiefer",
            "License": "LGPL",
            "Name": "Schiefer",
            "Version": "0.1",
        },
        "X-Plasma-API": "5.0",
    }
    with open(os.path.join(dest, "metadata.json"), "w") as f:
        json.dump(meta, f, indent=4, ensure_ascii=False)
    with open(os.path.join(dest, "plasmarc"), "w") as f:
        f.write("[ContrastEffect]\nenabled=false\n\n[BlurBehindEffect]\nenabled=false\n\n"
                "[AdaptiveTransparency]\nenabled=false\n")
    print(dest)


if __name__ == "__main__":
    build(DEST)
