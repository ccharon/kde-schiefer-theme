/*
 * Colors and base unit for all Schiefer login screens. Defaults = "Schiefer" palette;
 * lock screen, logout and splash set the values from the color scheme (Kirigami),
 * SDDM from theme.conf.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import "Motif.js" as Motif

QtObject {
    id: pal
    property color bg: "#bec2d3"          // Dialoge (CDE-Farbsatz 7)
    property color fg: "#000000"
    property color field: "#e2e5ed"       // Textfelder (Farbsatz 5)
    property color fieldText: "#000000"
    property color active: "#60729e"      // Aktivrahmen (Farbsatz 1)
    property color activeText: "#ffffff"
    property color panel: "#969eb8"       // Frontpanel (Farbsatz 8)
    property color panelText: "#000000"
    property color alert: "#a02828"
    property color lamp: "#e0a030"        // Startlampe wie am Dock
    // Font: the system font (lock/logout: Kirigami, SDDM: sddm.conf, often only 8 pt there),
    // enlarged for the centered panels; fontPoints > 0 fixes the size (SDDM: theme.conf).
    property font baseFont: Qt.application.font
    property real fontPoints: 0
    readonly property real basePoints: baseFont.pointSize > 0 ? baseFont.pointSize : (baseFont.pixelSize > 0 ? baseFont.pixelSize * 0.75 : 10)
    readonly property font font: Qt.font({
        family: baseFont.family,
        pointSize: fontPoints > 0 ? fontPoints : Math.max(12, Math.round(basePoints * 1.25)),
        weight: baseFont.weight
    })
    // Rasterized, hinted text as in Plasma; distance field text looks thin and ragged at scale 1
    readonly property int renderType: Text.NativeRendering

    property FontMetrics metrics: FontMetrics { font: pal.font }
    readonly property int u: Math.max(12, Math.round(metrics.height))   // base unit = line height

    function edges(c) { return Motif.colors(c); }
    // hover as in the dock: a third of the way to the Motif light edge
    function hover(c) { const t = Motif.colors(c).top; return Qt.rgba(c.r + (t.r - c.r) / 3, c.g + (t.g - c.g) / 3, c.b + (t.b - c.b) / 3, 1); }
}
