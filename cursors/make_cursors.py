#!/usr/bin/env python3
"""Schiefer mouse cursors: modern vector version of the classic X11 core cursors.

The shapes follow the glyphs of the X cursor font (left_ptr with a narrow tail, pocket watch,
thin crosshair, xterm bar with curved ends, double arrows, pencil, question mark with an
arrow ...), drawn as smooth vector shapes on a 24 px nominal grid (size like Breeze/Adwaita),
black with a white border or white with a black outline. No pixel scaling: every size is
rasterized separately with anti-aliasing.

Generates (Python standard library only; PIL only for --preview):
  svg/<name>.svg                   SVG sources (viewBox 24x24)
  Schiefer/index.theme             Inherits=breeze_cursors
  Schiefer/cursors/<name>          XCursor files (own rasterizer and writer, no xcursorgen)
  Schiefer/cursors_scalable/<n>/   SVG cursors + metadata.json (Plasma >= 6.2)
  aliases as symlinks (name list as in breeze_cursors plus X core names)

Usage:  make_cursors.py [--out DIR] [--preview PNG] [--check]

Origin and license: original drawings after the glyphs of the X cursor font
(cursorfont.h, (c) X Consortium, MIT license); no original bitmaps are used.
"""
import argparse, json, math, os, shutil, struct

HERE = os.path.dirname(os.path.abspath(__file__))
NOMINAL = 24                                   # nominal grid; size 24 = 1:1
SIZES = (24, 30, 32, 36, 40, 48, 60, 64, 72, 96)
BLACK, WHITE = (0, 0, 0), (255, 255, 255)
HALO = 1.0                                     # white border around black shapes (nominal px)
BORDER = 1.25                                  # black outline around white shapes

# ---------------------------------------------------------------- Geometry
def area(c):
    return sum(c[i][0] * c[i - 1][1] - c[i - 1][0] * c[i][1] for i in range(len(c))) / 2

def orient(c, outer=True):
    return c if (area(c) > 0) == outer else c[::-1]

def circle_pts(cx, cy, r, n=None):
    n = n or max(16, int(r * 10))
    return [(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n)) for i in range(n)]

def capsule_pts(p, q, r):
    (x0, y0), (x1, y1) = p, q
    a = math.atan2(y1 - y0, x1 - x0)
    n = max(8, int(r * 8))
    pts = [(x1 + r * math.cos(a - math.pi / 2 + math.pi * i / n), y1 + r * math.sin(a - math.pi / 2 + math.pi * i / n))
           for i in range(n + 1)]
    pts += [(x0 + r * math.cos(a + math.pi / 2 + math.pi * i / n), y0 + r * math.sin(a + math.pi / 2 + math.pi * i / n))
            for i in range(n + 1)]
    return pts

def rect_line_pts(p, q, w, ext=0.0):
    (x0, y0), (x1, y1) = p, q
    L = math.hypot(x1 - x0, y1 - y0)
    ux, uy = (x1 - x0) / L, (y1 - y0) / L
    nx, ny = -uy * w / 2, ux * w / 2
    x0, y0, x1, y1 = x0 - ux * ext, y0 - uy * ext, x1 + ux * ext, y1 + uy * ext
    return [(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)]

class Poly:
    """Filled polygon; grown = polygon plus capsules on all edges (round corners)."""
    def __init__(self, pts): self.pts = list(pts)
    def contours(self, t):
        out = [orient(self.pts)]
        if t > 0:
            n = len(self.pts)
            out += [orient(capsule_pts(self.pts[i], self.pts[(i + 1) % n], t)) for i in range(n)]
        return out
    def map(self, f, k): return Poly([f(p) for p in self.pts])

class Line:
    """Thick segment; cap 'round' (capsule) or 'butt' (rectangle, extended square when grown)."""
    def __init__(self, p, q, w, cap='butt'): self.p, self.q, self.w, self.cap = p, q, w, cap
    def contours(self, t):
        if self.cap == 'round':
            return [orient(capsule_pts(self.p, self.q, self.w / 2 + t))]
        return [orient(rect_line_pts(self.p, self.q, self.w + 2 * t, t))]
    def map(self, f, k): return Line(f(self.p), f(self.q), self.w * k, self.cap)

class PLine:
    """Polyline with round joints."""
    def __init__(self, pts, w): self.pts, self.w = list(pts), w
    def contours(self, t):
        r = self.w / 2 + t
        return [orient(capsule_pts(self.pts[i], self.pts[i + 1], r)) for i in range(len(self.pts) - 1)]
    def map(self, f, k): return PLine([f(p) for p in self.pts], self.w * k)

class Circle:
    def __init__(self, c, r): self.c, self.r = c, r
    def contours(self, t): return [orient(circle_pts(self.c[0], self.c[1], self.r + t))]
    def map(self, f, k): return Circle(f(self.c), self.r * k)

class Ring:
    def __init__(self, c, r, w): self.c, self.r, self.w = c, r, w      # r = Mittellinie
    def contours(self, t):
        ro, ri = self.r + self.w / 2 + t, self.r - self.w / 2 - t
        out = [orient(circle_pts(self.c[0], self.c[1], ro))]
        if ri > 0.2:
            out.append(orient(circle_pts(self.c[0], self.c[1], ri), outer=False))
        return out
    def map(self, f, k): return Ring(f(self.c), self.r * k, self.w * k)

def xform(prims, scale=1.0, angle=0.0, center=(12, 12), move=(0, 0), mirror_x=False, mirror_y=False):
    """Scale/rotate/mirror shapes around center, then translate."""
    ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    def f(p):
        x, y = p[0] - center[0], p[1] - center[1]
        if mirror_x: x = -x
        if mirror_y: y = -y
        x, y = (x * ca - y * sa) * scale, (x * sa + y * ca) * scale
        return (x + center[0] + move[0], y + center[1] + move[1])
    return [pr.map(f, scale) for pr in prims], f

def head(tip, direction, length=5.0, half=4.2):
    """Filled arrow head: tip at tip, pointing in direction (degrees, 0 = right, 90 = down)."""
    a = math.radians(direction)
    ux, uy = math.cos(a), math.sin(a)
    bx, by = tip[0] - ux * length, tip[1] - uy * length
    return Poly([tip, (bx - uy * half, by + ux * half), (bx + uy * half, by - ux * half)])

# ---------------------------------------------------------------- Layer styles
def solid(prims, halo=HALO):
    """Black shape with a white border (X11: black glyph, mask 1 px larger)."""
    return [(WHITE, prims, halo), (BLACK, prims, 0)]

def outlined(prims, details=(), border=BORDER, halo=HALO * 0.75):
    """White shape with a black outline (X11 hand, pencil); a narrow white rim outside."""
    return [(WHITE, prims, border + halo), (BLACK, prims, border), (WHITE, prims, 0),
            (BLACK, list(details), 0)]

# ---------------------------------------------------------------- Shapes (nominal grid 24)
ARROW = [(4, 3), (4, 18.2), (7.7, 14.7), (10.3, 20.4), (12.5, 19.4), (9.9, 13.8), (14.8, 13.8)]
ARROW_HOT = (4, 3)

def arrow(): return [Poly(ARROW)]

def watch_prims(c=(12, 12), r=6.2):
    cx, cy = c
    band = [Poly([(cx - 3.4, cy - r + 0.6), (cx - 2.6, cy - r - 2.9), (cx + 2.6, cy - r - 2.9), (cx + 3.4, cy - r + 0.6)]),
            Poly([(cx - 3.4, cy + r - 0.6), (cx - 2.6, cy + r + 2.9), (cx + 2.6, cy + r + 2.9), (cx + 3.4, cy + r - 0.6)])]
    crown = [Line((cx + r, cy), (cx + r + 2.2, cy), 2.2)]
    body = [Circle(c, r)] + band + crown
    face = [Circle(c, r - 1.7)]
    hands = [Line(c, (cx, cy - 3.6), 1.4, 'round'), Line(c, (cx + 2.7, cy + 1.2), 1.4, 'round')]
    return [(WHITE, body, HALO), (BLACK, body, 0), (WHITE, face, 0), (BLACK, hands, 0)]

def wait(): return watch_prims()

def progress():
    layers = solid(arrow())
    for col, prims, t in watch_prims():
        p, _ = xform(prims, scale=0.56, center=(12, 12), move=(5.6, 5.2))
        layers.append((col, p, t * 0.8))
    return layers

def crosshair():
    c = 12.5
    return solid([Line((c, 3.5), (c, 21.5), 1.0), Line((3.5, c), (21.5, c), 1.0)])

def cell():
    c = 12
    return solid([Line((c, 5), (c, 19), 3.0), Line((5, c), (19, c), 3.0)])

def x_cursor():
    return solid([Line((6, 6), (18, 18), 3.2), Line((18, 6), (6, 18), 3.2)])

def double_arrow(length=18.0, shaft=2.0, hl=5.0, hh=4.2, c=(12, 12)):
    x0, x1 = c[0] - length / 2, c[0] + length / 2
    return [Line((x0 + hl - 0.5, c[1]), (x1 - hl + 0.5, c[1]), shaft),
            head((x0, c[1]), 180, hl, hh), head((x1, c[1]), 0, hl, hh)]

def size_hor(): return solid(double_arrow())
def size_ver(): return solid(xform(double_arrow(), angle=90)[0])
def size_fdiag(): return solid(xform(double_arrow(length=17), angle=45)[0])
def size_bdiag(): return solid(xform(double_arrow(length=17), angle=-45)[0])

def fleur():
    p = []
    for ang in (0, 90, 180, 270):
        a = math.radians(ang)
        tip = (12 + 9 * math.cos(a), 12 + 9 * math.sin(a))
        p.append(head(tip, ang, 4.2, 3.6))
    p += [Line((12, 6.5), (12, 17.5), 2.0), Line((6.5, 12), (17.5, 12), 2.0)]
    return solid(p)

def single_arrow(direction):
    p = [Line((12, 20.5), (12, 8), 2.0), head((12, 3.5), 270, 5.5, 4.6)]
    return solid(xform(p, angle=direction + 90)[0])

def corner():
    p = [Line((3, 4), (13, 4), 2.0, 'butt'), Line((4, 3), (4, 13), 2.0, 'butt'),
         Line((18.5, 18.5), (10.5, 10.5), 2.0), head((7.5, 7.5), 225, 5.0, 4.0)]
    return solid(p)

def side():
    p = [Line((3.5, 4), (20.5, 4), 2.0), Line((12, 20.5), (12, 10.5), 2.0), head((12, 6.8), 270, 5.0, 4.2)]
    return solid(p)

def ibeam():
    c = 12.5
    top = [(9.6, 3.6), (11.3, 4.1), (c, 5.4), (13.7, 4.1), (15.4, 3.6)]
    bot = [(x, 25 - y) for x, y in top]
    return solid([PLine(top, 1.1), PLine(bot, 1.1), Line((c, 5.2), (c, 19.8), 1.1)])

def not_allowed():
    c, r = (12, 12), 7.0
    a = math.radians(45)
    d = (r * math.cos(a), r * math.sin(a))
    return solid([Ring(c, r, 2.2), Line((c[0] - d[0], c[1] - d[1]), (c[0] + d[0], c[1] + d[1]), 2.2)])

def magnifier(sign):
    c, r = (10, 10), 5.3
    p = [Ring(c, r, 1.9), Line((14.2, 14.2), (19.6, 19.6), 3.0, 'round'), Line((7.4, 10), (12.6, 10), 1.6)]
    if sign > 0:
        p.append(Line((10, 7.4), (10, 12.6), 1.6))
    return solid(p)

def split(vertical=False):
    p = [Line((10.5, 4), (10.5, 20), 1.0), Line((13.5, 4), (13.5, 20), 1.0),
         Line((8.4, 12), (6, 12), 2.0), head((3, 12), 180, 4.4, 3.8),
         Line((15.6, 12), (18, 12), 2.0), head((21, 12), 0, 4.4, 3.8)]
    return solid(xform(p, angle=90)[0] if vertical else p)

def pencil():
    tip = (4, 20)
    a = (math.sqrt(.5), -math.sqrt(.5)); n = (math.sqrt(.5), math.sqrt(.5))
    def P(u, v): return (tip[0] + u * a[0] + v * n[0], tip[1] + u * a[1] + v * n[1])
    body = [Poly([P(0, 0), P(5, 2.3), P(17.5, 2.3), P(17.5, -2.3), P(5, -2.3)])]
    det = [Poly([P(0, 0), P(1.9, 0.9), P(1.9, -0.9)]), Line(P(5, 2.3), P(5, -2.3), 0.9),
           Line(P(14.5, 2.3), P(14.5, -2.3), 0.9), Line(P(5.4, 0), P(14.1, 0), 0.7)]
    return outlined(body, det)

def question():
    c, r = (12, 7.6), 3.4
    arc = [(c[0] + r * math.cos(math.radians(a)), c[1] + r * math.sin(math.radians(a)))
           for a in range(195, 421, 15)]
    hook = arc + [(12.2, 11.6), (12, 12.8)]
    p = [PLine(hook, 2.1), Line((12, 12.8), (12, 17), 1.6), head((12, 21.4), 90, 4.8, 3.9)]
    return solid(p)

def hand(kind):
    """kind: 'point' (index finger up), 'open' (spread), 'closed' (fist)."""
    palm = Poly([(7.2, 12.0), (20.6, 12.4), (20.6, 16.6), (18.4, 21.0), (10.4, 21.0), (7.2, 17.0)])
    thumb = Line((4.9, 12.9), (8.4, 16.6), 3.1, 'round')
    if kind == 'point':
        fingers = [Line((9.3, 4.2), (9.3, 13), 3.5, 'round'), Line((12.9, 10.4), (12.9, 13.5), 3.3, 'round'),
                   Line((16.2, 11.0), (16.2, 13.8), 3.1, 'round'), Line((19.2, 12.0), (19.2, 14.3), 2.8, 'round')]
        det = [Line((11.1, 11.0), (11.1, 13.2), 0.8), Line((14.6, 11.4), (14.6, 13.6), 0.8),
               Line((17.8, 12.3), (17.8, 14.2), 0.8)]
    elif kind == 'open':
        fingers = [Line((9.0, 5.0), (9.6, 13), 3.1, 'round'), Line((12.6, 3.8), (12.8, 13), 3.1, 'round'),
                   Line((16.2, 4.8), (15.9, 13), 3.0, 'round'), Line((19.5, 7.4), (18.9, 14), 2.8, 'round')]
        thumb = Line((4.4, 10.6), (8.4, 16.4), 3.1, 'round')
        det = [Line((11.1, 9.5), (11.2, 13.2), 0.8), Line((14.4, 9.5), (14.4, 13.4), 0.8),
               Line((17.7, 10.5), (17.4, 13.8), 0.8)]
    else:
        fingers = [Line((9.2, 10.2), (9.2, 13), 3.1, 'round'), Line((12.5, 9.8), (12.5, 13), 3.1, 'round'),
                   Line((15.8, 10.0), (15.8, 13), 3.0, 'round'), Line((19.0, 10.8), (19.0, 13.6), 2.8, 'round')]
        thumb = Line((5.6, 13.6), (8.6, 16.4), 3.0, 'round')
        det = [Line((10.85, 9.6), (10.85, 12.6), 0.8), Line((14.15, 9.6), (14.15, 12.6), 0.8),
               Line((17.4, 10.0), (17.4, 13.0), 0.8)]
    prims, _ = xform([palm, thumb] + fingers, scale=0.92, center=(12, 21))
    det, _ = xform(det, scale=0.92, center=(12, 21))
    return outlined(prims, det)

def badge(symbol):
    """Arrow with a small sign at the bottom right (copy, link, ...)."""
    layers = solid(arrow())
    c = (19, 18.5)
    if symbol == 'plus':
        p = [Line((c[0], c[1] - 3.2), (c[0], c[1] + 3.2), 2.0), Line((c[0] - 3.2, c[1]), (c[0] + 3.2, c[1]), 2.0)]
        layers += solid(p)
    elif symbol == 'alias':
        p = [Line((16.4, 21.4), (20.2, 17.6), 1.8, 'round'), head((22.4, 15.4), -45, 3.6, 3.0)]
        layers += solid(p)
    elif symbol == 'no':
        p = [Ring(c, 3.0, 1.5), Line((c[0] - 2.1, c[1] - 2.1), (c[0] + 2.1, c[1] + 2.1), 1.5)]
        layers += solid(p)
    elif symbol == 'menu':
        box = [Poly([(15.5, 14.0), (22.0, 14.0), (22.0, 22.0), (15.5, 22.0)])]
        lines = [Line((17, y), (20.5, y), 1.0) for y in (16, 18, 20)]
        layers += outlined(box, lines, border=1.0, halo=0.75)
    return layers

# ---------------------------------------------------------------- Zeigertabelle
def build():
    """name -> (layers, hotspot in the nominal grid)"""
    A = {}
    A['default'] = (solid(arrow()), ARROW_HOT)
    A['right_ptr'] = (solid(xform(arrow(), mirror_x=True)[0]), (20, 3))
    A['center_ptr'] = (single_arrow(270), (12, 3.5))
    A['up-arrow'] = (single_arrow(270), (12, 3.5))
    A['down-arrow'] = (single_arrow(90), (12, 20.5))
    A['left-arrow'] = (single_arrow(180), (3.5, 12))
    A['right-arrow'] = (single_arrow(0), (20.5, 12))
    A['text'] = (ibeam(), (12.5, 12.5))
    A['vertical-text'] = ([(c, xform(p, angle=90, center=(12.5, 12.5))[0], t) for c, p, t in ibeam()], (12.5, 12.5))
    A["wait"] = (wait(), (12, 12))
    A['progress'] = (progress(), ARROW_HOT)
    A['crosshair'] = (crosshair(), (12.5, 12.5))
    A['cell'] = (cell(), (12, 12))
    A['x-cursor'] = (x_cursor(), (12, 12))
    A['fleur'] = (fleur(), (12, 12))
    A['size_hor'] = (size_hor(), (12, 12))
    A['size_ver'] = (size_ver(), (12, 12))
    A['size_fdiag'] = (size_fdiag(), (12, 12))
    A['size_bdiag'] = (size_bdiag(), (12, 12))
    co = corner()
    def flipped(layers, mx, my):
        return [(c, xform(p, mirror_x=mx, mirror_y=my)[0], t) for c, p, t in layers]
    A['top_left_corner'] = (co, (3, 3))
    A['top_right_corner'] = (flipped(co, True, False), (21, 3))
    A['bottom_left_corner'] = (flipped(co, False, True), (3, 21))
    A['bottom_right_corner'] = (flipped(co, True, True), (21, 21))
    si = side()
    A['top_side'] = (si, (12, 3))
    A['bottom_side'] = (flipped(si, False, True), (12, 21))
    A['left_side'] = ([(c, xform(p, angle=-90)[0], t) for c, p, t in si], (3, 12))
    A['right_side'] = ([(c, xform(p, angle=90)[0], t) for c, p, t in si], (21, 12))
    A['pointer'] = (hand('point'), (9.6, 3.3))
    A['openhand'] = (hand('open'), (12, 12))
    A['dnd-move'] = (hand('closed'), (12, 12))
    A['help'] = (question(), (12, 21.4))
    A['not-allowed'] = (not_allowed(), (12, 12))
    A['zoom-in'] = (magnifier(+1), (10, 10))
    A['zoom-out'] = (magnifier(-1), (10, 10))
    A['col-resize'] = (split(), (12, 12))
    A['row-resize'] = (split(True), (12, 12))
    A['pencil'] = (pencil(), (4, 20))
    A['copy'] = (badge('plus'), ARROW_HOT)
    A['alias'] = (badge('alias'), ARROW_HOT)
    A['dnd-no-drop'] = (badge('no'), ARROW_HOT)
    A['context-menu'] = (badge('menu'), ARROW_HOT)
    return A

# Aliases: name -> target (name list of breeze_cursors plus X core names)
ALIASES = {
    # X core names / classic
    'left_ptr': 'default', 'arrow': 'default', 'top_left_arrow': 'default', 'wayland-cursor': 'default',
    'size-bdiag': 'size_bdiag', 'size-fdiag': 'size_fdiag', 'size-hor': 'size_hor', 'size-ver': 'size_ver',
    'xterm': 'text', 'ibeam': 'text', 'watch': 'wait', 'clock': 'wait',
    'cross': 'crosshair', 'tcross': 'crosshair', 'color-picker': 'crosshair', 'target': 'crosshair',
    'size_all': 'fleur', 'all-scroll': 'fleur', 'move': 'fleur', 'all-resize': 'fleur',
    'hand1': 'pointer', 'hand2': 'pointer', 'pointing_hand': 'pointer',
    'grab': 'openhand', 'grabbing': 'dnd-move', 'closedhand': 'dnd-move', 'dnd-none': 'dnd-move',
    'sb_h_double_arrow': 'size_hor', 'h_double_arrow': 'size_hor', 'e-resize': 'size_hor',
    'w-resize': 'size_hor', 'ew-resize': 'size_hor', 'double_arrow': 'size_ver',
    'sb_v_double_arrow': 'size_ver', 'v_double_arrow': 'size_ver', 'n-resize': 'size_ver',
    's-resize': 'size_ver', 'ns-resize': 'size_ver',
    'nw-resize': 'size_fdiag', 'se-resize': 'size_fdiag', 'nwse-resize': 'size_fdiag',
    'ne-resize': 'size_bdiag', 'sw-resize': 'size_bdiag', 'nesw-resize': 'size_bdiag',
    'ul_angle': 'top_left_corner', 'ur_angle': 'top_right_corner',
    'll_angle': 'bottom_left_corner', 'lr_angle': 'bottom_right_corner',
    'sb_up_arrow': 'up-arrow', 'sb_down_arrow': 'down-arrow',
    'sb_left_arrow': 'left-arrow', 'sb_right_arrow': 'right-arrow',
    'question_arrow': 'help', 'whats_this': 'help', 'left_ptr_help': 'help',
    'left_ptr_watch': 'progress', 'half-busy': 'progress',
    'X_cursor': 'x-cursor', 'pirate': 'x-cursor',
    'circle': 'not-allowed', 'crossed_circle': 'not-allowed', 'forbidden': 'not-allowed',
    'no-drop': 'not-allowed',
    'link': 'alias', 'dnd-copy': 'copy', 'plus': 'cell',
    'split_h': 'col-resize', 'split_v': 'row-resize',
    'draft': 'pencil', 'draft_large': 'pencil', 'draft_small': 'pencil',
    # hash names (legacy Qt/GTK/Firefox names), targets as in breeze_cursors
    '00000000000000020006000e7e9ffc3f': 'progress', '08e8e1c95fe2fc01f976f1e063a24ccd': 'progress',
    '3ecb610c1bf2410f44200f48c40d3599': 'progress',
    '00008160000006810000408080010102': 'size_ver', '03b6e0fcb3499374a867c041f52298f0': 'not-allowed',
    '1081e37283d90000800003c07f3ef6bf': 'copy', '6407b0e94181790501fd1e167b474872': 'copy',
    'b66166c04f8c3109214a4fbd64a50fc8': 'copy',
    '3085a0e285430894940527032f8b26df': 'alias', '640fb0e74195791501fd1ed57b41487f': 'alias',
    'a2a266d0498c3104214a47bd64ab0fc8': 'alias',
    '4498f0e0c1937ffe01fd06f973665830': 'dnd-move', '9081237383d90e509aa00f00170e968f': 'dnd-move',
    'fcf21c00b30f7e3f83fe0dfd12e71cff': 'dnd-move',
    '5c6cd98b3f3ebcb1f9c7f1c204630408': 'help', 'd9ce0ab605698f320427677b458ad60b': 'help',
    '9d800788f1b08800ae810202380a0822': 'pointer', 'e29285e634086352946a0e7090d73106': 'pointer',
}

# ---------------------------------------------------------------- Rasterizing (anti-aliased)
SUB = 12                                         # subrows per pixel row; exact horizontal coverage

def coverage(contours, size):
    """Coverage 0..1 per pixel for the union of all contours (nonzero rule)."""
    s = size / NOMINAL
    rows = [[] for _ in range(size)]
    for c in contours:
        n = len(c)
        for i in range(n):
            (x0, y0), (x1, y1) = c[i - 1], c[i]
            x0, y0, x1, y1 = x0 * s, y0 * s, x1 * s, y1 * s
            if y0 == y1: continue
            d = 1 if y1 > y0 else -1
            if y0 > y1: x0, y0, x1, y1 = x1, y1, x0, y0
            e = (y0, y1, x0, (x1 - x0) / (y1 - y0), d)
            for r in range(max(0, int(y0)), min(size, int(math.ceil(y1)))):
                rows[r].append(e)
    cov = [0.0] * (size * size)
    w = 1.0 / SUB
    for r in range(size):
        edges = rows[r]
        if not edges: continue
        acc = [0.0] * (size + 1)
        for k in range(SUB):
            y = r + (k + 0.5) / SUB
            xs = sorted((x0 + (y - y0) * dx, d) for y0, y1, x0, dx, d in edges if y0 <= y < y1)
            wind = 0
            for i, (x, d) in enumerate(xs):
                before = wind
                wind += d
                if before == 0 and wind != 0:
                    a = x
                elif before != 0 and wind == 0:
                    b = x
                    a2, b2 = max(a, 0.0), min(b, float(size))
                    if b2 <= a2: continue
                    ia, ib = int(a2), int(b2)
                    if ia == ib:
                        acc[ia] += (b2 - a2) * w
                    else:
                        acc[ia] += (ia + 1 - a2) * w
                        for j in range(ia + 1, ib): acc[j] += w
                        acc[ib] += (b2 - ib) * w
        base = r * size
        for x in range(size):
            if acc[x]: cov[base + x] = min(1.0, acc[x])
    return cov

def layer_contours(prims, t):
    out = []
    for p in prims: out += p.contours(t)
    return out

def render(layers, size):
    """Stacked layers -> premultiplied ARGB pixels (as XCursor expects them)."""
    A = [0.0] * (size * size); R = [0.0] * (size * size); G = [0.0] * (size * size); B = [0.0] * (size * size)
    for col, prims, t in layers:
        if not prims: continue
        cov = coverage(layer_contours(prims, t), size)
        cr, cg, cb = (v / 255 for v in col)
        for i, a in enumerate(cov):
            if a:
                k = 1 - a
                A[i] = a + A[i] * k; R[i] = cr * a + R[i] * k; G[i] = cg * a + G[i] * k; B[i] = cb * a + B[i] * k
    px = []
    for i in range(size * size):
        q = lambda v: max(0, min(255, int(v * 255 + 0.5)))
        px.append(q(A[i]) << 24 | q(R[i]) << 16 | q(G[i]) << 8 | q(B[i]))
    return px

def svg(layers):
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">'
             % ((NOMINAL,) * 4)]
    for col, prims, t in layers:
        cs = layer_contours(prims, t)
        if not cs: continue
        d = ''.join('M' + 'L'.join('%.2f %.2f' % p for p in c) + 'Z' for c in cs)
        parts.append('<path fill="#%02x%02x%02x" fill-rule="nonzero" d="%s"/>' % (col + (d,)))
    parts.append('</svg>\n')
    return '\n'.join(parts)

def hotspot(h, size):
    s = size / NOMINAL
    return min(size - 1, int(h[0] * s)), min(size - 1, int(h[1] * s))

# ---------------------------------------------------------------- XCursor read/write
XC_MAGIC = b'Xcur'; XC_IMAGE = 0xfffd0002

def write_xcursor(path, images):
    """images: [(size, w, h, xhot, yhot, delay, pixels)]"""
    ntoc = len(images)
    toc = b''; body = b''; pos = 16 + 12 * ntoc
    for size, w, h, xh, yh, delay, px in images:
        chunk = struct.pack('<9I', 36, XC_IMAGE, size, 1, w, h, xh, yh, delay) + struct.pack('<%dI' % len(px), *px)
        toc += struct.pack('<3I', XC_IMAGE, size, pos)
        body += chunk; pos += len(chunk)
    with open(path, 'wb') as f:
        f.write(XC_MAGIC + struct.pack('<3I', 16, 0x10000, ntoc) + toc + body)

def read_xcursor(path):
    d = open(path, 'rb').read()
    if d[:4] != XC_MAGIC: raise ValueError('not an XCursor file: ' + path)
    hsz, ver, n = struct.unpack_from('<3I', d, 4)
    out = []
    for i in range(n):
        t, sub, pos = struct.unpack_from('<3I', d, hsz + 12 * i)
        _, t2, sz, v, w, h, xh, yh, dl = struct.unpack_from('<9I', d, pos)
        assert t2 == t == XC_IMAGE and sz == sub
        px = struct.unpack_from('<%dI' % (w * h), d, pos + 36)
        out.append((sz, w, h, xh, yh, dl, px))
    return out

# ---------------------------------------------------------------- Generation
INDEX = """[Icon Theme]
Name=Schiefer
Comment=Modern vector version of the classic X11 core cursors (black/white), part of the Schiefer theme
Inherits=breeze_cursors
"""

def _one(args):
    name, layers, hot = args
    imgs = []
    for size in SIZES:
        hx, hy = hotspot(hot, size)
        imgs.append((size, size, size, hx, hy, 0, render(layers, size)))
    return name, imgs

def generate(out, jobs=None):
    arts = build()
    theme = os.path.join(out, 'Schiefer')
    for d in (os.path.join(HERE, 'svg'), theme):
        shutil.rmtree(d, ignore_errors=True)
    os.makedirs(os.path.join(HERE, 'svg'))
    cdir = os.path.join(theme, 'cursors'); sdir = os.path.join(theme, 'cursors_scalable')
    os.makedirs(cdir); os.makedirs(sdir)
    with open(os.path.join(theme, 'index.theme'), 'w') as f: f.write(INDEX)
    work = [(n, l, h) for n, (l, h) in sorted(arts.items())]
    try:
        from multiprocessing import Pool
        with Pool(jobs) as pool: results = pool.map(_one, work)
    except (ImportError, OSError):
        results = [_one(w) for w in work]
    for name, imgs in results:
        layers, hot = arts[name]
        write_xcursor(os.path.join(cdir, name), imgs)
        s = svg(layers)
        open(os.path.join(HERE, 'svg', name + '.svg'), 'w').write(s)
        sd = os.path.join(sdir, name); os.makedirs(sd)
        open(os.path.join(sd, name + '.svg'), 'w').write(s)
        hx, hy = hotspot(hot, NOMINAL)
        with open(os.path.join(sd, 'metadata.json'), 'w') as f:
            json.dump([{'filename': name + '.svg', 'hotspot_x': hx, 'hotspot_y': hy,
                        'nominal_size': NOMINAL}], f, indent=4)
    for alias, target in sorted(ALIASES.items()):
        assert target in arts, (alias, target)
        for d in (cdir, sdir):
            os.symlink(target, os.path.join(d, alias))
    return theme, arts

def check(theme, arts):
    n = 0; bad = []
    for name in arts:
        imgs = read_xcursor(os.path.join(theme, 'cursors', name))
        assert [i[0] for i in imgs] == list(SIZES), name
        for sz, w, h, xh, yh, dl, px in imgs:
            assert w == h == sz and 0 <= xh < sz and 0 <= yh < sz, (name, sz)
            near = [px[y * w + x] >> 24 for y in range(max(0, yh - 1), min(h, yh + 2))
                    for x in range(max(0, xh - 1), min(w, xh + 2))]
            if max(near) == 0: bad.append('hotspot lies outside the shape: %s %d' % (name, sz))
        n += 1
        layers, _ = arts[name]
        pts = [p for _, prims, t in layers for c in layer_contours(prims, t) for p in c]
        lo = min(min(p) for p in pts); hi = max(max(p) for p in pts)
        if lo < 0 or hi > NOMINAL: bad.append('shape exceeds the grid: %s (%.2f..%.2f)' % (name, lo, hi))
    for a in ALIASES:
        assert os.path.exists(os.path.join(theme, 'cursors', a)), a
        assert os.path.exists(os.path.join(theme, 'cursors_scalable', a, 'metadata.json')), a
    if bad: raise SystemExit('\n'.join(bad))
    print('ok: %d cursors, %d aliases, sizes %s' % (n, len(ALIASES), SIZES))

def preview(theme, arts, png, size=32, zoom=3):
    """Contact sheet: every cursor at original size on light and dark, enlarged next to it."""
    from PIL import Image, ImageDraw
    names = sorted(arts)
    cols = 6
    cw, ch = size * 2 + size * zoom + 40, size * zoom + 26
    rows = (len(names) + cols - 1) // cols
    img = Image.new('RGB', (cols * cw + 10, rows * ch + 10), (104, 121, 155))
    dr = ImageDraw.Draw(img)
    for i, name in enumerate(names):
        sz, w, h, xh, yh, _, px = [x for x in read_xcursor(os.path.join(theme, 'cursors', name)) if x[0] == size][0]
        tile = Image.new('RGBA', (w, h))
        tile.putdata([((p >> 16) & 255, (p >> 8) & 255, p & 255, p >> 24) for p in px])
        # premultiplied -> straight alpha
        x0 = 10 + (i % cols) * cw; y0 = 10 + (i // cols) * ch
        dr.rectangle([x0, y0, x0 + size - 1, y0 + size - 1], fill=(200, 204, 212))
        dr.rectangle([x0, y0 + size, x0 + size - 1, y0 + 2 * size - 1], fill=(40, 44, 52))
        img.paste(tile, (x0, y0), tile); img.paste(tile, (x0, y0 + size), tile)
        big = tile.resize((w * zoom, h * zoom), Image.NEAREST)
        bx = x0 + size + 8
        dr.rectangle([bx, y0, bx + w * zoom - 1, y0 + h * zoom - 1], fill=(200, 204, 212))
        img.paste(big, (bx, y0), big)
        dr.line([bx + xh * zoom - 3, y0 + yh * zoom + 1, bx + xh * zoom + 5, y0 + yh * zoom + 1], fill=(255, 0, 0))
        dr.line([bx + xh * zoom + 1, y0 + yh * zoom - 3, bx + xh * zoom + 1, y0 + yh * zoom + 5], fill=(255, 0, 0))
        dr.text((x0, y0 + h * zoom + 4), name, fill=(255, 255, 255))
    img.save(png)

def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--out', default=HERE, help='output directory (default: cursors/); Schiefer/ is created inside')
    ap.add_argument('--preview', metavar='PNG', help='write a contact sheet (size 32, hotspot red)')
    ap.add_argument('--check', action='store_true', help='read the files back and check them')
    ap.add_argument('-j', '--jobs', type=int, default=None, help='processes (default: all cores)')
    a = ap.parse_args()
    theme, arts = generate(a.out, a.jobs)
    print('Theme:', theme, '-', len(arts), 'drawn cursors,', len(ALIASES), 'aliases')
    if a.check: check(theme, arts)
    if a.preview: preview(theme, arts, a.preview); print('Vorschau:', a.preview)

if __name__ == '__main__':
    main()
