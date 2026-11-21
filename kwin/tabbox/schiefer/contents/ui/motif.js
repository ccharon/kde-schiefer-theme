.pragma library
// Motif-Farbformel (lib/Xm/Color.c, CalculateColorsRGB) – JS-Fassung von common/schiefercolors.py,
// damit der Fensterwechsler dieselben Kanten wie Deko, Qt-Stil und Dock zeichnet.
// Copyright (c) 1987-2012 The Open Group, LGPL-2.1-or-later (Formel); geprüft gegen die Python-Fassung.

const MAX = 65535;
const PCT = Math.floor(MAX / 100);          // 655
const LITE_THRESHOLD = 93 * PCT;
const DARK_THRESHOLD = 20 * PCT;
const FG_THRESHOLD = 70 * PCT;

function cdiv(a, b) { return Math.trunc(a / b); }
function to16(c) { return Math.round(c * 255) * 257; }   // QML-Farbkanal 0…1 -> 16 bit über 8 bit
function to8(v) { return Math.floor((v * 255 + 32767) / 65535); }

function brightness16(r, g, b) {
    const intensity = Math.floor((r + g + b) / 3);
    const luminosity = Math.trunc(0.30 * r + 0.59 * g + 0.11 * b);
    return Math.floor((intensity * 75 + luminosity * 25) / 100);
}

// bg: QML-Farbe; Ergebnis {top, bottom, select, fg} als [r,g,b] in 0…255
function colors8(r8, g8, b8) {
    const bg = [r8 * 257, g8 * 257, b8 * 257];
    const br = brightness16(bg[0], bg[1], bg[2]);
    const black = f => bg.map(c => c - cdiv(c * f, 100));
    const white = f => bg.map(c => c + cdiv(f * (MAX - c), 100));
    let sel, bs, ts;
    if (br < DARK_THRESHOLD) {
        sel = white(15); bs = white(30); ts = white(50);
    } else if (br > LITE_THRESHOLD) {
        sel = black(15); bs = black(40); ts = black(20);
    } else {
        sel = black(15 + cdiv(br * (15 - 15), MAX));
        bs = black(60 + cdiv(br * (40 - 60), MAX));
        ts = white(50 + cdiv(br * (60 - 50), MAX));
    }
    const fg = br > FG_THRESHOLD ? [0, 0, 0] : [255, 255, 255];
    const e = v => v.map(to8);
    return { top: e(ts), bottom: e(bs), select: e(sel), fg: fg };
}

function colors(c) {
    const m = colors8(Math.round(c.r * 255), Math.round(c.g * 255), Math.round(c.b * 255));
    const q = v => Qt.rgba(v[0] / 255, v[1] / 255, v[2] / 255, 1);
    return { top: q(m.top), bottom: q(m.bottom), select: q(m.select), fg: q(m.fg) };
}
