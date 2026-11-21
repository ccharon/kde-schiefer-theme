/*
 * Emblem statt Herstellerlogo: drei gestaffelte Schieferplatten auf erhabener Kachel.
 * Farben aus der Palette (Aktivrahmen), Kanten nach der Motif-Formel.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import "Motif.js" as Motif

Bevel {
    id: em
    required property Pal pal
    base: pal.bg
    implicitWidth: 4 * pal.u
    implicitHeight: implicitWidth

    Canvas {
        id: cv
        anchors.fill: parent
        anchors.margins: 2
        onWidthChanged: requestPaint()
        Connections { target: em.pal; function onActiveChanged() { cv.requestPaint(); } }
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const s = width;
            const slate = em.pal.active;
            const m = Motif.colors(slate);
            const face = slate, lite = m.top, dark = m.bottom;
            const deep = Qt.darker(dark, 1.25);
            // Platte: Oberseite als Parallelogramm, darunter die Stirnkante
            const slab = (cx, cy, w, d, t) => {
                const k = Math.round(d * 0.9);           // Schräge der Oberseite
                const x0 = Math.round(cx - w / 2), x1 = Math.round(cx + w / 2), y = Math.round(cy);
                // Stirn (vorn) und Flanke (rechts)
                ctx.fillStyle = dark;
                ctx.beginPath();
                ctx.moveTo(x0, y + d); ctx.lineTo(x1 - k, y + d); ctx.lineTo(x1 - k, y + d + t); ctx.lineTo(x0, y + d + t);
                ctx.closePath(); ctx.fill();
                ctx.fillStyle = deep;
                ctx.beginPath();
                ctx.moveTo(x1 - k, y + d); ctx.lineTo(x1, y); ctx.lineTo(x1, y + t); ctx.lineTo(x1 - k, y + d + t);
                ctx.closePath(); ctx.fill();
                // Oberseite
                ctx.fillStyle = face;
                ctx.beginPath();
                ctx.moveTo(x0 + k, y); ctx.lineTo(x1, y); ctx.lineTo(x1 - k, y + d); ctx.lineTo(x0, y + d);
                ctx.closePath(); ctx.fill();
                // Lichtkante oben und links (1 px)
                ctx.fillStyle = lite;
                ctx.fillRect(x0 + k, y, x1 - x0 - k, 1);
                ctx.beginPath();
                ctx.moveTo(x0 + k, y); ctx.lineTo(x0 + k + 1, y); ctx.lineTo(x0 + 1, y + d); ctx.lineTo(x0, y + d);
                ctx.closePath(); ctx.fill();
            };
            const w = s * 0.62, d = Math.round(s * 0.16), t = Math.max(2, Math.round(s * 0.07));
            const step = Math.round(s * 0.2);
            const top = Math.round(s * 0.2);
            slab(s * 0.50 + s * 0.06, top + 2 * step, w, d, t);
            slab(s * 0.50 - s * 0.03, top + step, w, d, t);
            slab(s * 0.50 + s * 0.02, top, w, d, t);
        }
    }
}
