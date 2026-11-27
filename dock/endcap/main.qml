/*
 * Schiefer end piece: purely decorative end of the dock like the handles on the left and
 * right edge of the CDE front panel. At the top a raised button at the height of the tab row
 * (left with a raised bar, right with a small raised square), below it the ribbed grip.
 * As measured on CDE 2.5.3: button and grip are one block across the whole width; under the
 * button's dark lower edge the ribs alternate 1 px light and 1 px dark, with no surface between
 * them and no well, down to the ledge (or the panel's lower edge).
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
        // left: raised bar, right: small raised square (CDE: 12x4 and 4x4 px in a 19x13 button)
        Bevel {
            anchors.centerIn: parent
            // centered over the end piece itself, not over the part reaching into the gaps
            anchors.horizontalCenterOffset: (row.tabLeft - row.tabRight) / 2
            readonly property int thick: Math.max(4, Math.round(Math.min(knob.width, knob.height) * 0.3))
            readonly property int len: Math.max(6, Math.round((root.vertical ? root.height : root.width) * 0.6))
            width: root.rightSide ? thick : (root.vertical ? thick : len)
            height: root.rightSide ? thick : (root.vertical ? len : thick)
            depth: 1
        }
    }

    // ribbed grip: from the button down to the ledge (or the panel's lower edge), as wide as the
    // button, so on the outside it reaches the panel edge. Lines alternate light and dark, the
    // first one light right under the button's dark edge (vertical panel: columns, right of it).
    Canvas {
        id: ribs
        x: root.vertical ? knob.width : knob.x
        y: root.vertical ? 1 : knob.y + knob.height
        width: root.vertical ? root.width - knob.width : knob.width
        height: root.vertical ? root.height - 2
                              : Math.max(0, (row.ledge ? row.ledgeY : row.winSize.height - row.me.y) - y)
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: root
            function onLightColorChanged() { ribs.requestPaint(); }
            function onDarkColorChanged() { ribs.requestPaint(); }
        }
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = Math.floor(width), h = Math.floor(height);
            const n = root.vertical ? w : h;
            for (let p = 0; p < n; ++p) {
                ctx.fillStyle = p % 2 === 0 ? root.lightColor : root.darkColor;
                root.vertical ? ctx.fillRect(p, 0, 1, h) : ctx.fillRect(0, p, w, 1);
            }
        }
    }
}
