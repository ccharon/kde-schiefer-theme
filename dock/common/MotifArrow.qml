/*
 * Schiefer: Motif arrow (triangle with light and shadow edge)
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.kirigami as Kirigami

Canvas {
    id: arrow

    property bool up: true
    property bool sunken: false
    property color base: Kirigami.Theme.backgroundColor
    readonly property var motif: Scheme.motifColors(base)
    readonly property color lightColor: motif.top
    readonly property color darkColor: motif.bottom

    onUpChanged: requestPaint()
    onSunkenChanged: requestPaint()
    onBaseChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const w = Math.floor(width), h = Math.floor(height);
        // triangle with integer corners, tip up or down
        const l = 0.5, r = w - 0.5, mid = w / 2;
        const top = up ? 0.5 : h - 0.5, base_ = up ? h - 0.5 : 0.5;
        const lit = sunken ? darkColor : lightColor;
        const shade = sunken ? lightColor : darkColor;
        ctx.lineWidth = 1;
        ctx.fillStyle = base;
        ctx.beginPath(); ctx.moveTo(mid, top); ctx.lineTo(r, base_); ctx.lineTo(l, base_); ctx.closePath(); ctx.fill();
        // left flank light; right flank and base line (tip up) dark
        ctx.strokeStyle = up ? lit : shade;
        ctx.beginPath(); ctx.moveTo(l, base_); ctx.lineTo(mid, top); ctx.stroke();
        ctx.strokeStyle = shade;
        ctx.beginPath(); ctx.moveTo(mid, top); ctx.lineTo(r, base_); ctx.stroke();
        ctx.strokeStyle = up ? shade : lit;
        ctx.beginPath(); ctx.moveTo(r, base_); ctx.lineTo(l, base_); ctx.stroke();
    }
}
