"""
"Few colors" with dithering, as vectors without rasterizing.

Every fill color and gradient is mapped to a small palette. A color between two palette tones is
drawn as a checkerboard of both tones. The checkerboard is an SVG <pattern> inside a <mask>,
aligned to the grid of the root viewBox (1 cell = 1 pixel at nominal size). Shapes, edges and
anti-aliasing stay exactly as in Breeze.

For each element E whose color or gradient needs mixed tones:
    <g mask=A> E (fill = gradient/color tone 1) </g>
    <g mask=B> E' (fill = gradient/color tone 2) </g>
A and B are the two halves of the checkerboard. Every pixel belongs to exactly one, so
semi-transparent areas stay correct. Gradients become hard steps (equal offset values).
"""
import math, re
from functools import lru_cache
import numpy as np
from lxml import etree

SVG = "http://www.w3.org/2000/svg"
XL = "http://www.w3.org/1999/xlink"
Q = lambda t: f"{{{SVG}}}{t}"
SHAPES = {Q(t) for t in ("path", "rect", "circle", "ellipse", "polygon", "polyline", "line")}
NO_TOUCH = {Q(t) for t in ("defs", "clipPath", "mask", "pattern", "symbol", "marker", "linearGradient",
                           "radialGradient")}
NAMED = {"white": "ffffff", "black": "000000", "red": "ff0000", "none": None}


# --- Colors ---------------------------------------------------------------------------------
def srgb_lin(c):
    c = np.asarray(c, float) / 255.0
    return np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)

def lin_srgb(c):
    c = np.clip(c, 0, 1)
    return 255 * np.where(c > 0.0031308, 1.055 * c ** (1 / 2.4) - 0.055, 12.92 * c)

def to_lab(rgb):
    c = srgb_lin(rgb)
    xyz = c @ np.array([[0.4124, 0.2126, 0.0193], [0.3576, 0.7152, 0.1192], [0.1805, 0.0722, 0.9505]])
    xyz /= np.array([0.9505, 1.0, 1.089])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)

def parse_color(v):
    if v is None:
        return None
    v = v.strip().lower()
    if v in NAMED:
        v = NAMED[v]
        if v is None:
            return None
    elif v.startswith("#"):
        v = v[1:]
    else:
        return None
    if len(v) == 3:
        v = "".join(ch * 2 for ch in v)
    if not re.fullmatch(r"[0-9a-f]{6}", v):
        return None
    return tuple(int(v[i:i + 2], 16) for i in (0, 2, 4))

def hexc(rgb):
    return "#%02x%02x%02x" % tuple(int(round(c)) for c in rgb)


class Quantizer:
    """Palette plus 50/50 mixes of neighboring tones (checkerboard, mixed in linear light)."""

    def __init__(self, palette, sat=1.0, max_pair_de=38.0):
        self.pal = np.asarray(palette, float)
        self.sat = sat
        lab = to_lab(self.pal)
        lin = srgb_lin(self.pal)
        cand, cols = [], []
        n = len(self.pal)
        for i in range(n):
            cand.append((i, i)); cols.append(lab[i])
        for i in range(n):
            for j in range(i + 1, n):
                if np.sqrt(((lab[i] - lab[j]) ** 2).sum()) <= max_pair_de:
                    cand.append((i, j))
                    cols.append(to_lab(lin_srgb((lin[i] + lin[j]) / 2)[None])[0])
        self.cand = cand
        self.cand_lab = np.array(cols)
        self.pal_lab = lab

    def _pre(self, rgb):
        x = np.asarray(rgb, float)
        g = (x * [0.3, 0.59, 0.11]).sum()
        return np.clip(g + (x - g) * self.sat, 0, 255)

    @lru_cache(maxsize=None)
    def pair(self, rgb):
        lab = to_lab(self._pre(rgb)[None])[0]
        k = ((self.cand_lab - lab) ** 2).sum(-1).argmin()
        i, j = self.cand[k]
        return hexc(self.pal[i]), hexc(self.pal[j])

    @lru_cache(maxsize=None)
    def pure(self, rgb):
        lab = to_lab(self._pre(rgb)[None])[0]
        return hexc(self.pal[((self.pal_lab - lab) ** 2).sum(-1).argmin()])


# --- Style helpers ---------------------------------------------------------------------------
def get_style(el):
    s = {}
    for part in (el.get("style") or "").split(";"):
        if ":" in part:
            k, v = part.split(":", 1)
            s[k.strip()] = v.strip()
    return s

def prop(el, name):
    s = get_style(el)
    if name in s:
        return s[name]
    return el.get(name)

def set_prop(el, name, value):
    s = get_style(el)
    if name in s or el.get("style") and el.get(name) is None:
        s[name] = value
        el.set("style", ";".join(f"{k}:{v}" for k, v in s.items()))
        if el.get(name) is not None:
            del el.attrib[name]
    else:
        el.set(name, value)

def effective(el, name, default=None):
    while el is not None and isinstance(el.tag, str):
        v = prop(el, name)
        if v is not None and v != "inherit":
            return v
        el = el.getparent()
    return default


# --- Transforms ----------------------------------------------------------------------------
def parse_transform(t):
    m = np.eye(3)
    if not t:
        return m
    for fn, args in re.findall(r"(\w+)\s*\(([^)]*)\)", t):
        a = [float(x) for x in re.findall(r"[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?", args)]
        if fn == "matrix" and len(a) == 6:
            n = np.array([[a[0], a[2], a[4]], [a[1], a[3], a[5]], [0, 0, 1]])
        elif fn == "translate":
            n = np.array([[1, 0, a[0]], [0, 1, a[1] if len(a) > 1 else 0], [0, 0, 1]])
        elif fn == "scale":
            n = np.diag([a[0], a[1] if len(a) > 1 else a[0], 1])
        elif fn == "rotate":
            r = math.radians(a[0]); c, s = math.cos(r), math.sin(r)
            n = np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])
            if len(a) == 3:
                n = parse_transform(f"translate({a[1]},{a[2]})") @ n @ parse_transform(f"translate({-a[1]},{-a[2]})")
        elif fn == "skewX":
            n = np.array([[1, math.tan(math.radians(a[0])), 0], [0, 1, 0], [0, 0, 1]])
        elif fn == "skewY":
            n = np.array([[1, 0, 0], [math.tan(math.radians(a[0])), 1, 0], [0, 0, 1]])
        else:
            continue
        m = m @ n
    return m

def ancestors_ctm(el, root):
    m = np.eye(3)
    chain = []
    p = el.getparent()
    while p is not None and p is not root:
        chain.append(p)
        p = p.getparent()
    for p in reversed(chain):
        m = m @ parse_transform(p.get("transform"))
    return m


# --- Gradients ------------------------------------------------------------------------------
def stop_props(st):
    c = prop(st, "stop-color") or "#000000"
    o = prop(st, "stop-opacity")
    off = st.get("offset", "0").strip()
    off = float(off[:-1]) / 100 if off.endswith("%") else float(off or 0)
    return c, float(o) if o not in (None, "") else 1.0, off

def resolve_stops(grad, ids, depth=0):
    stops = [s for s in grad if s.tag == Q("stop")]
    if stops or depth > 10:
        return stops
    href = grad.get(f"{{{XL}}}href") or grad.get("href")
    if href and href.startswith("#") and href[1:] in ids:
        return resolve_stops(ids[href[1:]], ids, depth + 1)
    return []

GRAD_ATTRS = ("x1", "y1", "x2", "y2", "cx", "cy", "r", "fx", "fy", "fr", "gradientUnits",
              "gradientTransform", "spreadMethod")

def resolve_attrs(grad, ids):
    """Geometry attributes along the href chain (the element's own win)."""
    out, g, seen = {}, grad, set()
    while g is not None and id(g) not in seen:
        seen.add(id(g))
        for a in GRAD_ATTRS:
            if a not in out and g.get(a) is not None:
                out[a] = g.get(a)
        href = g.get(f"{{{XL}}}href") or g.get("href")
        g = ids.get(href[1:]) if href and href.startswith("#") else None
        if g is not None and g.tag != grad.tag:
            g = None  # stops may come from another gradient type, geometry may not
    return out

def sample_gradient(stops, n=96):
    """List (t, rgb, alpha) evenly over 0..1, None for currentColor and similar."""
    pts = []
    last = 0.0
    for st in stops:
        c, o, off = stop_props(st)
        rgb = parse_color(c)
        if rgb is None:
            return None
        off = max(last, min(1.0, off)); last = off
        pts.append((off, np.array(rgb, float), o))
    if not pts:
        return None
    out = []
    for k in range(n):
        t = (k + 0.5) / n
        if t <= pts[0][0]:
            rgb, a = pts[0][1], pts[0][2]
        elif t >= pts[-1][0]:
            rgb, a = pts[-1][1], pts[-1][2]
        else:
            for (o0, c0, a0), (o1, c1, a1) in zip(pts, pts[1:]):
                if o0 <= t <= o1:
                    f = 0 if o1 == o0 else (t - o0) / (o1 - o0)
                    rgb, a = c0 + (c1 - c0) * f, a0 + (a1 - a0) * f
                    break
        out.append((t, rgb, a))
    return out


class Ditherer:
    def __init__(self, quant, alpha_steps=4):
        self.q = quant
        self.alpha_steps = alpha_steps

    def qa(self, a):
        if a <= 0.02:
            return 0.0
        return max(1, round(a * self.alpha_steps)) / self.alpha_steps

    def bands(self, samples):
        """-> [(t_start, t_end, c1, c2, alpha)]"""
        out = []
        for t, rgb, a in samples:
            c1, c2 = self.q.pair(tuple(int(round(x)) for x in rgb))
            key = (c1, c2, self.qa(a))
            if out and out[-1][2:] == key:
                out[-1][1] = t
            else:
                out.append([t, t, *key])
        # boundaries halfway between two sample points
        for a, b in zip(out, out[1:]):
            m = (a[1] + b[0]) / 2
            a[1] = b[0] = m
        if out:
            out[0][0], out[-1][1] = 0.0, 1.0
        return out

    def process(self, svg_text, base, recolor_fallback):
        try:
            root = etree.fromstring(svg_text.encode("utf-8", "surrogateescape"),
                                    etree.XMLParser(huge_tree=True, remove_comments=False))
        except etree.XMLSyntaxError:
            return recolor_fallback(svg_text)
        if root.tag != Q("svg"):
            return recolor_fallback(svg_text)

        vb = [float(x) for x in re.split(r"[\s,]+", (root.get("viewBox") or "").strip()) if x] or None
        if not vb or len(vb) != 4:
            w = float(re.sub(r"[a-z%]+$", "", root.get("width", str(base))) or base)
            h = float(re.sub(r"[a-z%]+$", "", root.get("height", str(base))) or base)
            vb = [0, 0, w, h]
        unit = vb[2] / base  # 1 checkerboard cell = 1 pixel at nominal size

        ids = {e.get("id"): e for e in root.iter() if isinstance(e.tag, str) and e.get("id")}
        grads = {k: v for k, v in ids.items() if v.tag in (Q("linearGradient"), Q("radialGradient"))}

        defs = etree.Element(Q("defs"))
        root.insert(0, defs)
        counter = [0]
        def new_id(p):
            counter[0] += 1
            return f"sd{p}{counter[0]}"

        # checkerboard pattern (root coordinates)
        def checker(cells):
            pid = new_id("p")
            p = etree.SubElement(defs, Q("pattern"), id=pid, patternUnits="userSpaceOnUse",
                                 x=f"{vb[0]:g}", y=f"{vb[1]:g}", width=f"{2 * unit:g}", height=f"{2 * unit:g}")
            for cx, cy in cells:
                etree.SubElement(p, Q("rect"), x=f"{cx * unit:g}", y=f"{cy * unit:g}",
                                 width=f"{unit:g}", height=f"{unit:g}", fill="#ffffff")
            return pid
        pat = {}
        masks = {}
        def mask_pair(ctm):
            key = tuple(np.round(ctm[:2].ravel(), 6))
            if key in masks:
                return masks[key]
            if not pat:
                pat["A"] = checker([(0, 0), (1, 1)])
                pat["B"] = checker([(1, 0), (0, 1)])
            inv = np.linalg.inv(ctm)
            tr = "matrix(%s)" % " ".join(f"{v:.8g}" for v in (inv[0, 0], inv[1, 0], inv[0, 1], inv[1, 1], inv[0, 2], inv[1, 2]))
            res = []
            for half in ("A", "B"):
                mid = new_id("m")
                m = etree.SubElement(defs, Q("mask"), id=mid, maskUnits="userSpaceOnUse",
                                     x="-100000", y="-100000", width="200000", height="200000")
                r = etree.SubElement(m, Q("rect"), x=f"{vb[0]:g}", y=f"{vb[1]:g}",
                                     width=f"{vb[2]:g}", height=f"{vb[3]:g}", fill=f"url(#{pat[half]})")
                if not np.allclose(inv, np.eye(3)):
                    r.set("transform", tr)
                res.append(mid)
            masks[key] = res
            return res

        made = {}   # (gradient-id) -> (g1-id, g2-id or None)
        def gradient_variant(gid):
            if gid in made:
                return made[gid]
            g = grads[gid]
            samples = sample_gradient(resolve_stops(g, ids))
            if samples is None:
                made[gid] = None
                return None
            bands = self.bands(samples)
            mixed = any(b[2] != b[3] for b in bands)
            out = []
            for which in (2, 3) if mixed else (2,):
                nid = new_id("g")
                ng = etree.SubElement(defs, g.tag, id=nid)
                for k, v in resolve_attrs(g, ids).items():
                    ng.set(k, v)
                for t0, t1, *cc in bands:
                    for t in (t0, t1):
                        etree.SubElement(ng, Q("stop"), offset=f"{t:.4f}",
                                         style=f"stop-color:{cc[which - 2]};stop-opacity:{cc[2]:g}")
                out.append(nid)
            made[gid] = (out[0], out[1] if mixed else None)
            return made[gid]

        def in_defs(el):
            p = el.getparent()
            while p is not None:
                if p.tag in NO_TOUCH:
                    return True
                p = p.getparent()
            return False

        targets = [e for e in root.iter() if isinstance(e.tag, str) and e.tag in SHAPES and not in_defs(e)]
        for el in targets:
            fill = effective(el, "fill", "#000000")
            v1 = v2 = None
            m = re.fullmatch(r"url\(\s*#([^)\s]+)\s*\)(.*)", fill.strip())
            if m and m.group(1) in grads:
                r = gradient_variant(m.group(1))
                if r:
                    v1, v2 = f"url(#{r[0]})", (f"url(#{r[1]})" if r[1] else None)
            else:
                rgb = parse_color(fill)
                if rgb is not None:
                    c1, c2 = self.q.pair(rgb)
                    v1, v2 = c1, (c2 if c2 != c1 else None)
            stroke = effective(el, "stroke")
            if stroke:
                ms = re.fullmatch(r"url\(\s*#([^)\s]+)\s*\)(.*)", stroke.strip())
                if ms and ms.group(1) in grads:
                    r = gradient_variant(ms.group(1))
                    if r:
                        set_prop(el, "stroke", f"url(#{r[0]})")
                elif parse_color(stroke):
                    set_prop(el, "stroke", self.q.pure(parse_color(stroke)))
            if v1 is None:
                continue
            set_prop(el, "fill", v1)
            if v2 is None:
                continue
            ma, mb = mask_pair(ancestors_ctm(el, root))
            parent = el.getparent()
            idx = parent.index(el)
            ga = etree.Element(Q("g"), mask=f"url(#{ma})")
            gb = etree.Element(Q("g"), mask=f"url(#{mb})")
            parent.remove(el)
            tail, el.tail = el.tail, None
            clone = etree.fromstring(etree.tostring(el))
            for e in clone.iter():
                if isinstance(e.tag, str) and "id" in e.attrib:
                    del e.attrib["id"]
            set_prop(clone, "fill", v2)
            ga.append(el); gb.append(clone)
            parent.insert(idx, ga); parent.insert(idx + 1, gb)
            gb.tail = tail

        if not len(defs):
            root.remove(defs)
        text = etree.tostring(root, encoding="unicode")
        # remaining color values (gradients elsewhere, flood-color, CSS classes) to plain palette tones
        return recolor_fallback(text)
