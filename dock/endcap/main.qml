/*
 * Schiefer end piece: purely decorative end of the dock like the handles on the left and
 * right edge of the CDE front panel. At the top a raised button at the height of the tab row
 * (left with a bar, right with a small square), below it a ribbed grip.
 * Sizes match the drawer (tab height, spacing).
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool rightSide: Plasmoid.configuration.side === "right"
    // same as org.kde.schiefer.drawer
    readonly property int tabSize: Math.max(10, Math.round(Kirigami.Units.gridUnit * 0.7))
    readonly property int pad: Kirigami.Units.smallSpacing
    readonly property int thickness: Math.max(12, Kirigami.Units.gridUnit)

    readonly property color base: Kirigami.Theme.backgroundColor
    readonly property var motif: Scheme.motifColors(base)
    readonly property color lightColor: motif.top
    readonly property color darkColor: motif.bottom

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    // option frontpanel-color: surfaces in the CDE front panel color instead of the window color;
    // children inherit it through Kirigami.Theme, FrameTint also tints the panel background
    Kirigami.Theme.inherit: !Scheme.usePanelColor
    Kirigami.Theme.backgroundColor: Scheme.usePanelColor ? Scheme.panelColor : undefined
    FrameTint {}
    // DockRow: the button joins the tab row of the drawers, the ledge runs underneath
    readonly property bool schieferTabRow: true
    readonly property bool schieferLedge: true
    DockRow {
        id: row
        target: root
        vertical: root.vertical
    }
    Ledge { row: row }
    Plasmoid.icon: "align-horizontal-left"
    toolTipMainText: ""

    Layout.minimumWidth: vertical ? -1 : thickness
    Layout.maximumWidth: vertical ? -1 : thickness
    Layout.minimumHeight: vertical ? thickness : -1
    Layout.maximumHeight: vertical ? thickness : -1

    // button in the tab row (top, or left on a vertical panel)
    Item {
        id: knob
        x: -row.tabLeft
        y: -row.raiseAbove
        width: root.vertical ? root.tabSize + Scheme.tabRaise : parent.width + row.tabLeft + row.tabRight
        height: root.vertical ? parent.height : root.tabSize + Scheme.tabRaise
        Bevel {
            anchors.fill: parent
            anchors.topMargin: root.vertical ? 1 : 0
            anchors.bottomMargin: root.vertical ? 1 : 0
            // only slightly raised, like the tabs next to it
            depth: 1
        }
        // left: engraved bar, right: small raised square
        Bevel {
            anchors.centerIn: parent
            // centered over the end piece itself, not over the part reaching into the gaps
            anchors.horizontalCenterOffset: (row.tabLeft - row.tabRight) / 2
            readonly property int len: Math.max(4, Math.round(Math.min(knob.width, knob.height) * (root.rightSide ? 0.36 : 0.5)))
            width: root.rightSide ? len : (root.vertical ? 3 : len)
            height: root.rightSide ? len : (root.vertical ? len : 3)
            depth: 1
            sunken: !root.rightSide
        }
    }

    // ribbed grip in a flat well
    Bevel {
        id: well
        anchors {
            left: root.vertical ? knob.right : parent.left
            top: root.vertical ? parent.top : knob.bottom
            right: parent.right
            bottom: parent.bottom
            leftMargin: root.vertical ? root.pad : 1
            rightMargin: root.vertical ? root.pad : 1
            topMargin: root.vertical ? 1 : root.pad
            bottomMargin: root.vertical ? 1 : Math.max(root.pad, row.ledgeOverlap + 1)
        }
        sunken: true
        depth: 1
    }
    Canvas {
        id: ribs
        anchors.fill: well
        anchors.margins: 2
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = Math.floor(width), h = Math.floor(height);
            // grooves: dark line with a light line below, one row of background between them
            for (let p = 0; p + 1 < (root.vertical ? w : h); p += 3) {
                ctx.fillStyle = root.darkColor;
                root.vertical ? ctx.fillRect(p, 0, 1, h) : ctx.fillRect(0, p, w, 1);
                ctx.fillStyle = root.lightColor;
                root.vertical ? ctx.fillRect(p + 1, 0, 1, h) : ctx.fillRect(0, p + 1, w, 1);
            }
        }
    }
}
