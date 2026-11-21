.pragma library
// Patterns and color levels of the Schiefer backdrop.

// key = file name in contents/patterns (index tiles from make_index_tiles.py); keys are stored in user configs
const PATTERNS = [
    { key: "koeper",   name: "Twill" },
    { key: "leinen",   name: "Linen" },
    { key: "rauten",   name: "Diamonds" },
    { key: "granit",   name: "Granite" },
    { key: "wellen",   name: "Waves" },
    { key: "pflaster", name: "Paving" },
    { key: "flach",    name: "Solid" },
];

// Offsets of the six palette levels from the base color (level 2), from RAMP in make_patterns.py;
// with the base color #68799b this gives exactly the original slate blue palette.
const RAMP_DELTA = [[-20, -23, -27], [-10, -11, -13], [0, 0, 0], [10, 11, 11], [22, 22, 21], [36, 35, 33]];

function indexOf(key) {
    for (let i = 0; i < PATTERNS.length; ++i)
        if (PATTERNS[i].key === key) return i;
    return -1;
}

// "a, b,c" or ["a","b"] -> ["a","b","c"]
function parseList(v) {
    const a = Array.isArray(v) ? v : String(v ?? "").split(",");
    return a.map(s => String(s).trim()).filter(s => s.length > 0);
}

// entry i of a list; shorter lists repeat
function pick(list, i, fallback) {
    return list.length ? list[i % list.length] : fallback;
}

// extend the list so entry i exists (with the values in effect so far), then set it
function setAt(str, i, value, fallback) {
    const a = parseList(str);
    const n = a.length;
    const out = [];
    for (let k = 0; k < Math.max(n, i + 1); ++k)
        out.push(n ? a[k % n] : fallback);
    out[i] = value;
    return out.join(",");
}

// base color -> six levels. If a level leaves 0..255, the whole channel is shifted to keep
// the relief (very light or dark colors are adjusted slightly for this).
function ramp(c) {
    const base = [Math.round(c.r * 255), Math.round(c.g * 255), Math.round(c.b * 255)];
    const shift = [0, 1, 2].map(k => {
        const lo = base[k] + RAMP_DELTA[0][k], hi = base[k] + RAMP_DELTA[5][k];
        return hi > 255 ? 255 - hi : lo < 0 ? -lo : 0;
    });
    return RAMP_DELTA.map(d => Qt.rgba((base[0] + d[0] + shift[0]) / 255,
                                       (base[1] + d[1] + shift[1]) / 255,
                                       (base[2] + d[2] + shift[2]) / 255, 1));
}

// color from text; invalid -> fallback
function toColor(s, fallback) {
    try {
        const c = Qt.color(String(s ?? "").trim());
        if (c && c.valid) return c;
    } catch (e) {}
    return typeof fallback === "string" ? Qt.color(fallback) : fallback;
}
