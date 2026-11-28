/*
 * Picture panel on the right of the login dialog, like the vendor logo of dtlogin: sunken,
 * filled with an ordered-dither gradient in the active frame color, the three slate plates of the
 * emblem in the middle (no tile, no text).
 * theme.conf "logo" puts an image there instead.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import "kit"
import "kit/Motif.js" as Motif

Bevel {
    id: logo
    required property Pal pal
    property string image
    base: pal.bg
    sunken: true
    implicitWidth: 13 * pal.u

    readonly property var shades: Motif.colors(pal.active)
    readonly property color topColor: Qt.tint(pal.active, Qt.rgba(shades.top.r, shades.top.g, shades.top.b, 0.35))
    readonly property color bottomColor: Qt.tint(pal.active, Qt.rgba(shades.bottom.r, shades.bottom.g, shades.bottom.b, 0.7))

    // dithered gradient from a lighter top to the Motif shadow color at the bottom: bands with
    // Qt's dense brush patterns, the stipples of X11 bitmaps
    Canvas {
        id: dither
        x: logo.depth; y: logo.depth
        width: logo.width - 2 * logo.depth; height: logo.height - 2 * logo.depth
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: logo; function onTopColorChanged() { dither.requestPaint(); } function onBottomColorChanged() { dither.requestPaint(); } }
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const top = logo.topColor, bottom = logo.bottomColor;
            ctx.fillStyle = top;
            ctx.fillRect(0, 0, width, height);
            const steps = [Qt.Dense7Pattern, Qt.Dense6Pattern, Qt.Dense5Pattern, Qt.Dense4Pattern,
                           Qt.Dense3Pattern, Qt.Dense2Pattern, Qt.Dense1Pattern, Qt.SolidPattern];
            const band = height / (steps.length + 1);
            for (let i = 0; i < steps.length; ++i) {
                const y0 = Math.round(band * (i + 1));
                const y1 = i === steps.length - 1 ? height : Math.round(band * (i + 2));
                ctx.fillStyle = steps[i] === Qt.SolidPattern ? bottom : ctx.createPattern(bottom, steps[i]);
                ctx.fillRect(0, y0, width, y1 - y0);
            }
        }
    }

    readonly property int inner: Math.min(width, height) - 2 * depth - 2 * Math.round(pal.u * 0.8)

    Image {
        visible: logo.image !== ""
        source: logo.image !== "" ? Qt.resolvedUrl(logo.image) : ""
        anchors.fill: parent
        anchors.margins: logo.depth + Math.round(logo.pal.u * 0.8)
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
    Emblem {
        visible: logo.image === ""
        pal: logo.pal
        tile: false
        anchors.centerIn: parent
        width: Math.min(logo.inner, 10 * logo.pal.u)
        height: width
    }
}
