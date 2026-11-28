/*
 * Picture panel on the right of the login dialog, like the vendor logo of dtlogin: sunken, filled
 * with an ordered-dither gradient in the active frame color, emblem and name on top, the
 * seven-segment clock with the date at the bottom. theme.conf "logo" replaces emblem and name
 * with an image.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import "kit"
import "kit/Motif.js" as Motif

Bevel {
    id: logo
    required property Pal pal
    property string image
    property string name: "Schiefer"
    property bool showClock: true
    property date now: new Date()
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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: logo.depth + Math.round(logo.pal.u * 0.8)
        spacing: Math.round(logo.pal.u * 0.5)

        Image {
            visible: logo.image !== ""
            source: logo.image !== "" ? Qt.resolvedUrl(logo.image) : ""
            fillMode: Image.PreserveAspectFit
            smooth: true
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
        RowLayout {
            visible: logo.image === ""
            spacing: Math.round(logo.pal.u * 0.6)
            Layout.alignment: Qt.AlignHCenter
            Emblem { pal: logo.pal; implicitWidth: 3 * logo.pal.u }
            Text {
                renderType: logo.pal.renderType
                text: logo.name
                color: Motif.colors(logo.topColor).fg
                font.family: logo.pal.font.family
                font.pixelSize: Math.round(logo.pal.u * 1.5)
                font.bold: true
            }
        }
        Item { visible: logo.image === ""; Layout.fillHeight: true }

        SevenSeg {
            visible: logo.showClock
            pal: logo.pal
            base: logo.pal.active
            now: logo.now
            Layout.alignment: Qt.AlignHCenter
        }
        Text {
            visible: logo.showClock
            renderType: logo.pal.renderType
            Layout.alignment: Qt.AlignHCenter
            text: logo.now.toLocaleDateString(Qt.locale(), "ddd, d. MMM yyyy")
            font: logo.pal.font
            color: Motif.colors(logo.bottomColor).fg
        }
    }
}
