/*
 * Joins the Schiefer dock widgets of a horizontal panel into one front panel as in CDE:
 *  - tab row: tabs and end piece buttons reach halfway into the gap to a neighboring tab
 *    widget (to the panel edge when there is no neighbor), so neighbors touch
 *  - tabs grow upward by Scheme.tabRaise into the padding above the applet
 *  - ledge at the bottom of the panel (Scheme.ledge) under every Schiefer dock widget
 * Other widgets in the same panel stay untouched. A widget opts in with the properties
 * schieferTabRow / schieferLedge on its PlasmoidItem. Vertical panels get none of this.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.ksvg as KSvg
import org.kde.kirigami as Kirigami

Item {
    id: row

    required property Item target
    required property bool vertical
    // width of the raised panel edge (plasma/make_plasma_theme.py: raised(2))
    property int bevel: 2

    property rect me: Qt.rect(0, 0, target.width, target.height)
    property size winSize: Qt.size(target.width, target.height)
    property int borders: KSvg.FrameSvg.AllBorders
    // horizontal gap to the neighbor before/after; -1: no neighbor (panel edge)
    property int gapBefore: -1
    property int gapAfter: -1
    property bool tabsBefore: false
    property bool tabsAfter: false
    property bool ledgeBefore: false
    property bool ledgeAfter: false

    readonly property bool active: !vertical
    readonly property int edgeL: (borders & KSvg.FrameSvg.LeftBorder) ? bevel : 0
    readonly property int edgeR: (borders & KSvg.FrameSvg.RightBorder) ? bevel : 0
    readonly property int edgeT: (borders & KSvg.FrameSvg.TopBorder) ? bevel : 0

    function reach(gap, joined, toEdge, first) {
        if (gap < 0) return Math.max(0, toEdge);
        return joined ? (first ? Math.ceil(gap / 2) : Math.floor(gap / 2)) : 0;
    }
    // how far the tab row reaches beyond the applet on the left and right
    readonly property int tabLeft: active ? reach(gapBefore, tabsBefore, me.x - edgeL, true) : 0
    readonly property int tabRight: active ? reach(gapAfter, tabsAfter, winSize.width - edgeR - me.x - me.width, false) : 0
    // the part of Scheme.tabRaise that fits above the applet; the rest makes the tab taller downward
    readonly property int raise: Math.max(0, Scheme.tabRaise)
    readonly property int raiseAbove: active ? Math.min(raise, Math.max(0, me.y - edgeT)) : 0
    readonly property int raiseBelow: raise - raiseAbove

    // ledge: dark line, 2 px panel surface, 2 px shadow at the bottom of the panel window
    readonly property bool ledge: active && Scheme.ledge
    readonly property int ledgeHeight: 5
    readonly property int ledgeLeft: ledge ? reach(gapBefore, ledgeBefore, me.x - edgeL, true) : 0
    readonly property int ledgeRight: ledge ? reach(gapAfter, ledgeAfter, winSize.width - edgeR - me.x - me.width, false) : 0
    // ledge top in applet coordinates, and how much of the applet it covers
    readonly property int ledgeY: winSize.height - me.y - ledgeHeight
    readonly property int ledgeOverlap: ledge ? Math.max(0, target.height - ledgeY + 1) : 0

    // the marked item (schieferLedge defined) inside an applet container, or null
    function dockItem(c, depth) {
        if (c.schieferLedge !== undefined) return c;
        if (depth <= 0) return null;
        for (const k of c.children) {
            const f = dockItem(k, depth - 1);
            if (f) return f;
        }
        return null;
    }

    function measure() {
        const w = row.Window.window;
        const container = target.parent;
        if (!w || !container || !container.parent) return;
        const p = target.mapToItem(null, 0, 0);
        me = Qt.rect(Math.round(p.x), Math.round(p.y), target.width, target.height);
        winSize = Qt.size(w.width, w.height);

        let before = null, after = null, bGap = -1, aGap = -1;
        for (const c of container.parent.children) {
            if (c === container || !c.visible || c.width <= 0 || c.height <= 0) continue;
            const d = dockItem(c, 3);
            const it = d || c;
            const q = it.mapToItem(null, 0, 0);
            const l = Math.round(q.x), r = Math.round(q.x) + it.width;
            if (r <= me.x && (bGap < 0 || me.x - r < bGap)) { bGap = me.x - r; before = d; }
            else if (l >= me.x + me.width && (aGap < 0 || l - me.x - me.width < aGap)) { aGap = l - me.x - me.width; after = d; }
        }
        gapBefore = bGap;
        gapAfter = aGap;
        tabsBefore = !!(before && before.schieferTabRow);
        tabsAfter = !!(after && after.schieferTabRow);
        ledgeBefore = !!before;
        ledgeAfter = !!after;

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

    // measure after applets and window have settled
    Timer {
        id: measureTimer
        interval: 250
        running: true
        onTriggered: row.measure()
    }
    Connections {
        target: row.target
        function onXChanged() { measureTimer.restart(); }
        function onYChanged() { measureTimer.restart(); }
        function onWidthChanged() { measureTimer.restart(); }
        function onHeightChanged() { measureTimer.restart(); }
        function onParentChanged() { measureTimer.restart(); }
    }
    Connections {
        target: row.target.parent
        function onXChanged() { measureTimer.restart(); }
        function onYChanged() { measureTimer.restart(); }
        function onWidthChanged() { measureTimer.restart(); }
    }
    // applets added, removed or resized in the same panel
    Connections {
        target: row.target.parent ? row.target.parent.parent : null
        function onChildrenChanged() { measureTimer.restart(); }
        function onWidthChanged() { measureTimer.restart(); }
        function onImplicitWidthChanged() { measureTimer.restart(); }
    }
    Connections {
        target: row.Window.window
        function onWidthChanged() { measureTimer.restart(); }
        function onHeightChanged() { measureTimer.restart(); }
    }
}
