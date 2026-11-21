/*
 * Lage eines Applets im Leistenfenster. Plasma polstert Applets ungleich (längs 8 px
 * plus Rest, quer 4 px) und weiß nichts von der erhabenen Leistenkante. Diese
 * Komponente misst Lage, Fenstergröße, sichtbare Kanten und das überschüssige Polster,
 * damit das Applet seinen Inhalt mit gleichem Rand zwischen die sichtbaren Kanten
 * setzen und eine um das Polster gekürzte Länge melden kann. Der Inhalt ragt dafür
 * über das Applet hinaus (nichts clippt, Klicks gehen).
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.ksvg as KSvg

Item {
    id: fit

    required property Item target
    required property bool vertical
    // Rand zwischen Inhalt und sichtbarer Leistenkante, ringsum gleich
    property int gap: 3
    // Breite der erhabenen Leistenkante (plasma/make_plasma_theme.py: raised(2))
    property int bevel: 2

    property point winPos: Qt.point(0, 0)
    property size winSize: Qt.size(target.width, target.height)
    property int borders: KSvg.FrameSvg.AllBorders
    property int excess: 0
    // das Applet ist allein sichtbar in seiner Leiste
    property bool alone: true

    readonly property int edgeL: (borders & KSvg.FrameSvg.LeftBorder) ? bevel : 0
    readonly property int edgeR: (borders & KSvg.FrameSvg.RightBorder) ? bevel : 0
    readonly property int edgeT: (borders & KSvg.FrameSvg.TopBorder) ? bevel : 0
    readonly property int edgeB: (borders & KSvg.FrameSvg.BottomBorder) ? bevel : 0
    readonly property int edgesAlong: vertical ? edgeT + edgeB : edgeL + edgeR
    // Dicke zwischen den sichtbaren Kanten
    readonly property int thickness: vertical ? winSize.width - edgeL - edgeR : winSize.height - edgeT - edgeB
    // Innenfläche (Fenster ohne Kanten und Rand) in Koordinaten des Applets
    readonly property int innerX: edgeL + gap - winPos.x
    readonly property int innerY: edgeT + gap - winPos.y
    readonly property int innerWidth: winSize.width - edgeL - edgeR - 2 * gap
    readonly property int innerHeight: winSize.height - edgeT - edgeB - 2 * gap

    // Länge, die das Applet melden muss, damit das Fenster Kanten + Rand + Inhalt umfasst
    function lengthFor(contentLength) {
        return Math.max(1, edgesAlong + 2 * gap + contentLength - excess);
    }

    function measure() {
        const w = fit.Window.window;
        if (!w || !target.parent) {
            return;
        }
        const p = target.mapToItem(null, 0, 0);
        winPos = Qt.point(Math.round(p.x), Math.round(p.y));
        winSize = Qt.size(w.width, w.height);
        let others = 0;
        const container = target.parent;
        if (container.parent) {
            for (const c of container.parent.children) {
                if (c !== container && c.visible && (vertical ? c.height : c.width) > 0) {
                    ++others;
                }
            }
        }
        alone = others === 0;
        // Polster nur messen, wenn das Fenster frei der gemeldeten Länge folgt; steht es
        // an seiner Mindest- oder Höchstlänge (Leiste mit eigener Länge), steckt im
        // Unterschied auch Leerraum, und die gemeldete Länge liefe davon
        const winLen = vertical ? w.height : w.width;
        // lengthMode 2 = PanelView::Custom
        const clamped = w.lengthMode === 2 && ((w.minimumLength !== undefined && w.minimumLength > 0 && winLen <= w.minimumLength)
                     || (w.maximumLength !== undefined && w.maximumLength > 0 && winLen >= w.maximumLength));
        if (!alone) {
            excess = 0;
        } else if (!clamped) {
            excess = Math.max(0, winLen - (vertical ? target.height : target.width));
        }
        // sichtbarer Leistenrahmen: das sichtbare FrameSvgItem in Fenstergröße
        for (let it = target.parent; it; it = it.parent) {
            for (const c of it.children) {
                if (c.enabledBorders !== undefined && c.visible && c.width === w.width && c.height === w.height) {
                    borders = c.enabledBorders;
                    return;
                }
            }
        }
    }

    // erst messen, wenn Applet und Fenster zur Ruhe gekommen sind; das Fenster folgt
    // der gemeldeten Länge verzögert, sofortiges Messen schaukelt sich auf
    Timer {
        id: measureTimer
        interval: 250
        running: true
        onTriggered: fit.measure()
    }
    Connections {
        target: fit.target
        function onXChanged() { measureTimer.restart(); }
        function onYChanged() { measureTimer.restart(); }
        function onWidthChanged() { measureTimer.restart(); }
        function onHeightChanged() { measureTimer.restart(); }
        function onParentChanged() { measureTimer.restart(); }
    }
    Connections {
        target: fit.Window.window
        function onWidthChanged() { measureTimer.restart(); }
        function onHeightChanged() { measureTimer.restart(); }
    }
    Connections {
        target: fit.target.parent
        function onXChanged() { measureTimer.restart(); }
        function onYChanged() { measureTimer.restart(); }
    }
}
