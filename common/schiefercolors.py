"""Schiefer color core after Motif (Python version of schiefercolors.h).

Motif derives foreground, top and bottom shadow and select color from a background color.
The formula is taken exactly from Motif 2.3.8
(lib/Xm/Color.c: Brightness, CalculateColorsFor{Light,Dark,Medium}Background,
CalculateColorsRGB; constants from lib/Xm/ColorP.h and lib/Xm/Xm.h.in),
Copyright (c) 1987-2012 The Open Group, LGPL-2.1-or-later.

Like Motif it computes with 16 bits per channel (8 bit -> c * 257, as XQueryColor on
TrueColor screens) and C integer division (truncation toward zero). The way back to 8 bit
rounds like Qt (QColor::fromRgba64(v).red() = round(v / 257)), so Python and C++
(schiefercolors.h) give the same values. common/test_colors.py checks this.

    motif_colors((190, 194, 211))
    -> {'fg': (0,0,0), 'top': (227,229,236), 'bottom': (105,107,116), 'select': (162,165,179), 'model': 'medium'}

SPDX-License-Identifier: LGPL-2.1-or-later
"""

# lib/Xm/ColorP.h
XmMAX_SHORT = 65535
XmCOLOR_PERCENTILE = XmMAX_SHORT // 100          # 655

XmRED_LUMINOSITY = 0.30
XmGREEN_LUMINOSITY = 0.59
XmBLUE_LUMINOSITY = 0.11

XmINTENSITY_FACTOR = 75
XmLIGHT_FACTOR = 0
XmLUMINOSITY_FACTOR = 25

XmCOLOR_LITE_SEL_FACTOR = 15                      # toward black
XmCOLOR_LITE_BS_FACTOR = 40
XmCOLOR_LITE_TS_FACTOR = 20

XmCOLOR_DARK_SEL_FACTOR = 15                      # toward white
XmCOLOR_DARK_BS_FACTOR = 30
XmCOLOR_DARK_TS_FACTOR = 50

XmCOLOR_HI_SEL_FACTOR = 15
XmCOLOR_HI_BS_FACTOR = 40
XmCOLOR_HI_TS_FACTOR = 60

XmCOLOR_LO_SEL_FACTOR = 15
XmCOLOR_LO_BS_FACTOR = 60
XmCOLOR_LO_TS_FACTOR = 50

# lib/Xm/Xm.h.in (defaults of the XmScreen resources, in percent)
XmDEFAULT_DARK_THRESHOLD = 20
XmDEFAULT_LIGHT_THRESHOLD = 93
XmDEFAULT_FOREGROUND_THRESHOLD = 70

# Color.c: GetDefaultThresholdsForScreen
XmCOLOR_LITE_THRESHOLD = XmDEFAULT_LIGHT_THRESHOLD * XmCOLOR_PERCENTILE        # 60915
XmCOLOR_DARK_THRESHOLD = XmDEFAULT_DARK_THRESHOLD * XmCOLOR_PERCENTILE          # 13100
XmFOREGROUND_THRESHOLD = XmDEFAULT_FOREGROUND_THRESHOLD * XmCOLOR_PERCENTILE    # 45850


def _cdiv(a, b):
    """Integer division as in C (truncates toward zero, not down)."""
    q = abs(a) // abs(b)
    return q if (a >= 0) == (b >= 0) else -q


def to16(c):
    return c * 257


def to8(v):
    """16 -> 8 bit like Qt (QColor::red() of a 16-bit color = round(v / 257))."""
    return (v * 255 + 32767) // 65535


def brightness16(rgb16):
    """Color.c: Brightness(), 0 ... 65535."""
    red, green, blue = rgb16
    intensity = (red + green + blue) // 3
    luminosity = int((XmRED_LUMINOSITY * float(red))
                     + (XmGREEN_LUMINOSITY * float(green))
                     + (XmBLUE_LUMINOSITY * float(blue)))
    maxprimary = max(red, green, blue)
    minprimary = min(red, green, blue)
    light = (minprimary + maxprimary) // 2
    return ((intensity * XmINTENSITY_FACTOR)
            + (light * XmLIGHT_FACTOR)
            + (luminosity * XmLUMINOSITY_FACTOR)) // 100


def model(rgb):
    """'dark', 'light' or 'medium' (which branch of CalculateColorsRGB applies)."""
    b = brightness16(tuple(to16(c) for c in rgb[:3]))
    if b < XmCOLOR_DARK_THRESHOLD:
        return "dark"
    if b > XmCOLOR_LITE_THRESHOLD:
        return "light"
    return "medium"


def brightness(rgb):
    """Motif brightness of an 8-bit color as a fraction 0 ... 1."""
    return brightness16(tuple(to16(c) for c in rgb[:3])) / XmMAX_SHORT


def motif_colors16(bg16):
    """Color.c: CalculateColorsRGB() on 16-bit values -> dict with fg/top/bottom/select (16 bit)."""
    b = brightness16(bg16)
    fg = (0, 0, 0) if b > XmFOREGROUND_THRESHOLD else (XmMAX_SHORT,) * 3

    def toward_black(f):
        return tuple(c - _cdiv(c * f, 100) for c in bg16)

    def toward_white(f):
        return tuple(c + _cdiv(f * (XmMAX_SHORT - c), 100) for c in bg16)

    if b < XmCOLOR_DARK_THRESHOLD:
        m = "dark"
        sel = toward_white(XmCOLOR_DARK_SEL_FACTOR)
        bs = toward_white(XmCOLOR_DARK_BS_FACTOR)
        ts = toward_white(XmCOLOR_DARK_TS_FACTOR)
    elif b > XmCOLOR_LITE_THRESHOLD:
        m = "light"
        sel = toward_black(XmCOLOR_LITE_SEL_FACTOR)
        bs = toward_black(XmCOLOR_LITE_BS_FACTOR)
        ts = toward_black(XmCOLOR_LITE_TS_FACTOR)
    else:
        m = "medium"
        f = XmCOLOR_LO_SEL_FACTOR + _cdiv(b * (XmCOLOR_HI_SEL_FACTOR - XmCOLOR_LO_SEL_FACTOR), XmMAX_SHORT)
        sel = toward_black(f)
        f = XmCOLOR_LO_BS_FACTOR + _cdiv(b * (XmCOLOR_HI_BS_FACTOR - XmCOLOR_LO_BS_FACTOR), XmMAX_SHORT)
        bs = toward_black(f)
        f = XmCOLOR_LO_TS_FACTOR + _cdiv(b * (XmCOLOR_HI_TS_FACTOR - XmCOLOR_LO_TS_FACTOR), XmMAX_SHORT)
        ts = toward_white(f)
    return {"fg": fg, "top": ts, "bottom": bs, "select": sel, "model": m}


def motif_colors(rgb):
    """8-bit color (r, g, b) -> dict fg/top/bottom/select as 8-bit tuples, plus 'model'."""
    c16 = motif_colors16(tuple(to16(c) for c in rgb[:3]))
    out = {k: tuple(to8(v) for v in c16[k]) for k in ("fg", "top", "bottom", "select")}
    out["model"] = c16["model"]
    return out


# ---------------------------------------------------------------- small helpers

def parse(spec):
    """'#rrggbb', 'r,g,b' or tuple -> (r, g, b)."""
    if isinstance(spec, (tuple, list)):
        return tuple(int(v) for v in spec[:3])
    s = spec.strip()
    if s.startswith("#"):
        return tuple(int(s[i:i + 2], 16) for i in (1, 3, 5))
    return tuple(int(v) for v in s.split(",")[:3])


def hexcolor(rgb):
    return "#%02x%02x%02x" % tuple(rgb[:3])


def kde(rgb):
    """KDE notation 'r,g,b'."""
    return "%d,%d,%d" % tuple(rgb[:3])


def mix(a, b, t):
    """Linear mix like KColorUtils::mix (sRGB), rounded."""
    return tuple(int(round(x + (y - x) * t)) for x, y in zip(a[:3], b[:3]))


def qgray(rgb):
    """Qt: qGray() = (11 r + 16 g + 5 b) / 32."""
    r, g, b = rgb[:3]
    return (r * 11 + g * 16 + b * 5) // 32


def factors(rgb):
    """Mix fractions of the Motif formula for an 8-bit color: (top, bottom, select) as 0 ... 1.

    In the medium branch  top = mix(bg, white, top),  bottom = mix(bg, black, bottom),
    select = mix(bg, black, select). Styles that cannot compute (Plasma SVG, GTK CSS) use
    these as a fixed approximation around a reference color. In the dark and light branches a
    negative value means the opposite direction (dark: bottom/select toward white; light: top toward black)."""
    b = brightness16(tuple(to16(c) for c in rgb[:3]))
    if b < XmCOLOR_DARK_THRESHOLD:
        return (XmCOLOR_DARK_TS_FACTOR / 100, -XmCOLOR_DARK_BS_FACTOR / 100, -XmCOLOR_DARK_SEL_FACTOR / 100)
    if b > XmCOLOR_LITE_THRESHOLD:
        return (-XmCOLOR_LITE_TS_FACTOR / 100, XmCOLOR_LITE_BS_FACTOR / 100, XmCOLOR_LITE_SEL_FACTOR / 100)
    ts = XmCOLOR_LO_TS_FACTOR + _cdiv(b * (XmCOLOR_HI_TS_FACTOR - XmCOLOR_LO_TS_FACTOR), XmMAX_SHORT)
    bs = XmCOLOR_LO_BS_FACTOR + _cdiv(b * (XmCOLOR_HI_BS_FACTOR - XmCOLOR_LO_BS_FACTOR), XmMAX_SHORT)
    sel = XmCOLOR_LO_SEL_FACTOR + _cdiv(b * (XmCOLOR_HI_SEL_FACTOR - XmCOLOR_LO_SEL_FACTOR), XmMAX_SHORT)
    return (ts / 100, bs / 100, sel / 100)
