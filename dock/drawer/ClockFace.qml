/*
 * Digital clock in Motif style: sunken display in dark slate,
 * seven-segment digits in light blue gray, unlit segments faintly visible.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: clock

    property date now: new Date()
    readonly property color base: Kirigami.Theme.backgroundColor
    readonly property color screenColor: Qt.tint(base, Qt.rgba(0.08, 0.10, 0.16, 0.72))
    readonly property color litColor: Qt.tint(Qt.tint(base, Qt.rgba(1, 1, 1, 0.8)), Qt.rgba(
        Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.2))

    Bevel {
        id: screen
        anchors.centerIn: parent
        width: parent.width
        height: Math.round(parent.height * 0.58)
        sunken: true
        base: clock.base
        fill: clock.screenColor

        Canvas {
            id: digits
            anchors.fill: parent
            anchors.margins: screen.depth + 2
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: clock
                function onNowChanged() { digits.requestPaint(); }
                function onLitColorChanged() { digits.requestPaint(); }
            }

            //  aaa
            // f   b
            //  ggg
            // e   c
            //  ddd
            readonly property var segs: ["abcdef", "bc", "abdeg", "abcdg", "bcfg", "acdfg", "acdefg", "abc", "abcdefg", "abcdfg"]

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                // room: 4 digits, 2 gaps, 1 colon (widths in digit widths)
                const units = 4 + 2 * 0.22 + 0.55;
                let dw = width / units;
                let dh = dw * 1.75;
                if (dh > height) { dh = height; dw = dh / 1.75; }
                const t = Math.max(2, dw * 0.22);      // segment thickness
                const gap = dw * 0.22, cw = dw * 0.55;
                let x = (width - dw * units) / 2;
                const y = (height - dh) / 2;
                const lit = clock.litColor;
                const off = Qt.rgba(lit.r, lit.g, lit.b, 0.05);

                // segment as a hexagon with pointed ends
                const hSeg = (sx, sy, len) => {
                    ctx.beginPath();
                    ctx.moveTo(sx, sy);
                    ctx.lineTo(sx + t / 2, sy - t / 2);
                    ctx.lineTo(sx + len - t / 2, sy - t / 2);
                    ctx.lineTo(sx + len, sy);
                    ctx.lineTo(sx + len - t / 2, sy + t / 2);
                    ctx.lineTo(sx + t / 2, sy + t / 2);
                    ctx.closePath();
                    ctx.fill();
                };
                const vSeg = (sx, sy, len) => {
                    ctx.beginPath();
                    ctx.moveTo(sx, sy);
                    ctx.lineTo(sx + t / 2, sy + t / 2);
                    ctx.lineTo(sx + t / 2, sy + len - t / 2);
                    ctx.lineTo(sx, sy + len);
                    ctx.lineTo(sx - t / 2, sy + len - t / 2);
                    ctx.lineTo(sx - t / 2, sy + t / 2);
                    ctx.closePath();
                    ctx.fill();
                };
                const digit = (n, dx) => {
                    const on = segs[n];
                    const l = dx + t / 2, r = dx + dw - t / 2;
                    const top = y + t / 2, mid = y + dh / 2, bot = y + dh - t / 2;
                    const sp = Math.max(0.5, t * 0.12);   // gap between the segments
                    const hl = r - l - 2 * sp, vl = mid - top - 2 * sp;
                    const parts = {
                        a: () => hSeg(l + sp, top, hl),
                        g: () => hSeg(l + sp, mid, hl),
                        d: () => hSeg(l + sp, bot, hl),
                        f: () => vSeg(l, top + sp, vl),
                        b: () => vSeg(r, top + sp, vl),
                        e: () => vSeg(l, mid + sp, vl),
                        c: () => vSeg(r, mid + sp, vl)
                    };
                    for (const s in parts) {
                        ctx.fillStyle = on.indexOf(s) >= 0 ? lit : off;
                        parts[s]();
                    }
                };

                const h = clock.now.getHours(), m = clock.now.getMinutes();
                digit(Math.floor(h / 10), x); x += dw + gap;
                digit(h % 10, x); x += dw;
                // colon: two square dots
                ctx.fillStyle = lit;
                const p = t, cx = x + (cw - p) / 2;
                ctx.fillRect(Math.round(cx), Math.round(y + dh * 0.3 - p / 2), Math.round(p), Math.round(p));
                ctx.fillRect(Math.round(cx), Math.round(y + dh * 0.7 - p / 2), Math.round(p), Math.round(p));
                x += cw;
                digit(Math.floor(m / 10), x); x += dw + gap;
                digit(m % 10, x);
            }
        }
    }
}
