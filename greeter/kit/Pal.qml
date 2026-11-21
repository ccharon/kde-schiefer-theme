/*
 * Farben und Grundmaß für alle Schiefer-Anmeldeteile. Vorgabe = Palette „Schiefer“;
 * Sperrbildschirm, Abmelden und Startbild setzen die Werte aus dem Farbschema (Kirigami),
 * SDDM aus theme.conf.
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
    property font font: Qt.application.font

    property FontMetrics metrics: FontMetrics { font: pal.font }
    readonly property int u: Math.max(12, Math.round(metrics.height))   // Grundmaß = Zeilenhöhe

    function edges(c) { return Motif.colors(c); }
    // Hover wie im Dock: ein Drittel des Wegs zur Motif-Lichtkante
    function hover(c) { const t = Motif.colors(c).top; return Qt.rgba(c.r + (t.r - c.r) / 3, c.g + (t.g - c.g) / 3, c.b + (t.b - c.b) / 3, 1); }
}
