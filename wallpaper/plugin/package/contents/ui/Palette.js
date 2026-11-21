.pragma library
// Muster und Farbabstufung des Schiefer-Hintergrunds.

// Schlüssel = Dateiname in contents/patterns (Index-Kacheln aus make_index_tiles.py)
const PATTERNS = [
    { key: "koeper",   name: "Köper" },
    { key: "leinen",   name: "Leinen" },
    { key: "rauten",   name: "Rauten" },
    { key: "granit",   name: "Granit" },
    { key: "wellen",   name: "Wellen" },
    { key: "pflaster", name: "Pflaster" },
    { key: "flach",    name: "Einfarbig" },
];

// Abstand der sechs Palettenstufen zum Grundton (Stufe 2), aus RAMP in make_patterns.py;
// mit dem Grundton #68799b entsteht genau die ursprüngliche Schieferblau-Palette.
const RAMP_DELTA = [[-20, -23, -27], [-10, -11, -13], [0, 0, 0], [10, 11, 11], [22, 22, 21], [36, 35, 33]];

function indexOf(key) {
    for (let i = 0; i < PATTERNS.length; ++i)
        if (PATTERNS[i].key === key) return i;
    return -1;
}

// "a, b,c" oder ["a","b"] -> ["a","b","c"]
function parseList(v) {
    const a = Array.isArray(v) ? v : String(v ?? "").split(",");
    return a.map(s => String(s).trim()).filter(s => s.length > 0);
}

// Eintrag i einer Liste, kürzere Listen wiederholen sich
function pick(list, i, fallback) {
    return list.length ? list[i % list.length] : fallback;
}

// Liste so verlängern, dass Eintrag i existiert (mit den bisher wirksamen Werten), dann setzen
function setAt(str, i, value, fallback) {
    const a = parseList(str);
    const n = a.length;
    const out = [];
    for (let k = 0; k < Math.max(n, i + 1); ++k)
        out.push(n ? a[k % n] : fallback);
    out[i] = value;
    return out.join(",");
}

// Grundton -> sechs Stufen. Läuft eine Stufe aus 0..255, wird der ganze Kanal verschoben,
// damit das Relief erhalten bleibt (sehr helle/dunkle Farben werden dafür leicht angepasst).
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

// Farbe aus Text, ungültig -> fallback
function toColor(s, fallback) {
    try {
        const c = Qt.color(String(s ?? "").trim());
        if (c && c.valid) return c;
    } catch (e) {}
    return typeof fallback === "string" ? Qt.color(fallback) : fallback;
}
