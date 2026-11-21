/*
 * Position of an applet in the panel window. Plasma pads applets unevenly (8 px along
 * plus remainder, 4 px across) and knows nothing of the raised panel edge. This
 * component measures position, window size, visible edges and the extra padding,
 * so the applet can place its content with an even margin between the visible edges
 * and report a length reduced by the padding. The content extends beyond the applet
 * for this (nothing clips, clicks work).
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.ksvg as KSvg

Item {
    id: fit

    required property Item target
    required property bool vertical
    // margin between content and visible panel edge, equal on all sides
    property int gap: 3
    // width of the raised panel edge (plasma/make_plasma_theme.py: raised(2))
    property int bevel: 2

    property point winPos: Qt.point(0, 0)
    property size winSize: Qt.size(target.width, target.height)
    property int borders: KSvg.FrameSvg.AllBorders
    property int excess: 0
    // the applet is the only visible one in its panel
    property bool alone: true

    readonly property int edgeL: (borders & KSvg.FrameSvg.LeftBorder) ? bevel : 0
    readonly property int edgeR: (borders & KSvg.FrameSvg.RightBorder) ? bevel : 0
    readonly property int edgeT: (borders & KSvg.FrameSvg.TopBorder) ? bevel : 0
    readonly property int edgeB: (borders & KSvg.FrameSvg.BottomBorder) ? bevel : 0
    readonly property int edgesAlong: vertical ? edgeT + edgeB : edgeL + edgeR
    // thickness between the visible edges
    readonly property int thickness: vertical ? winSize.width - edgeL - edgeR : winSize.height - edgeT - edgeB
    // inner area (window without edges and margin) in applet coordinates
    readonly property int innerX: edgeL + gap - winPos.x
    readonly property int innerY: edgeT + gap - winPos.y
    readonly property int innerWidth: winSize.width - edgeL - edgeR - 2 * gap
    readonly property int innerHeight: winSize.height - edgeT - edgeB - 2 * gap

    // length the applet must report so the window covers edges + margin + content
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
        // Measure the padding only while the window follows the reported length freely. At
        // its minimum or maximum length (panel with a custom length) the difference also
        // contains empty space, and the reported length would run away
        const winLen = vertical ? w.height : w.width;
        // lengthMode 2 = PanelView::Custom
        const clamped = w.lengthMode === 2 && ((w.minimumLength !== undefined && w.minimumLength > 0 && winLen <= w.minimumLength)
                     || (w.maximumLength !== undefined && w.maximumLength > 0 && winLen >= w.maximumLength));
        if (!alone) {
            excess = 0;
        } else if (!clamped) {
            excess = Math.max(0, winLen - (vertical ? target.height : target.width));
        }
        // visible panel frame: the visible FrameSvgItem of window size
        for (let it = target.parent; it; it = it.parent) {
            for (const c of it.children) {
                if (c.enabledBorders !== undefined && c.visible && c.width === w.width && c.height === w.height) {
                    borders = c.enabledBorders;
                    return;
                }
            }
        }
    }

    // measure only after applet and window have settled; the window follows the
    // reported length with a delay, and measuring right away oscillates
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
