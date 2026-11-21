/*
 * Schiefer-Abschluss: rein dekoratives End-Stück des Docks wie die Griffe am linken und
 * rechten Rand des CDE-Frontpanels. Oben ein erhabener Knopf in Höhe der Laschenreihe
 * (links mit Strich, rechts mit kleinem Quadrat), darunter eine geriffelte Griffleiste.
 * Maße wie bei der Schublade (Laschenhöhe, Abstände), damit es dazugehört.
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
    // wie org.kde.schiefer.drawer
    readonly property int tabSize: Math.max(10, Math.round(Kirigami.Units.gridUnit * 0.7))
    readonly property int pad: Kirigami.Units.smallSpacing
    readonly property int thickness: Math.max(12, Kirigami.Units.gridUnit)

    readonly property color base: Kirigami.Theme.backgroundColor
    readonly property var motif: Scheme.motifColors(base)
    readonly property color lightColor: motif.top
    readonly property color darkColor: motif.bottom

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    // Schalter frontpanel-farbe: Flächen in der CDE-Frontpanel-Farbe statt der Fensterfarbe;
    // Kinder erben sie über Kirigami.Theme, FrameTint färbt den Leistenhintergrund mit
    Kirigami.Theme.inherit: !Scheme.usePanelColor
    Kirigami.Theme.backgroundColor: Scheme.usePanelColor ? Scheme.panelColor : undefined
    FrameTint {}
    Plasmoid.icon: "align-horizontal-left"
    toolTipMainText: ""

    Layout.minimumWidth: vertical ? -1 : thickness
    Layout.maximumWidth: vertical ? -1 : thickness
    Layout.minimumHeight: vertical ? thickness : -1
    Layout.maximumHeight: vertical ? thickness : -1

    // Knopf in der Laschenreihe (oben bzw. bei senkrechter Leiste links)
    Item {
        id: knob
        x: 0; y: 0
        width: root.vertical ? root.tabSize : parent.width
        height: root.vertical ? parent.height : root.tabSize
        Bevel {
            anchors.fill: parent
            anchors.leftMargin: root.vertical ? 0 : 1
            anchors.rightMargin: root.vertical ? 0 : 1
            anchors.topMargin: root.vertical ? 1 : 0
            anchors.bottomMargin: root.vertical ? 1 : 0
        }
        // links: eingravierter Strich, rechts: kleines erhabenes Quadrat
        Bevel {
            anchors.centerIn: parent
            readonly property int len: Math.max(4, Math.round(Math.min(knob.width, knob.height) * (root.rightSide ? 0.36 : 0.5)))
            width: root.rightSide ? len : (root.vertical ? 3 : len)
            height: root.rightSide ? len : (root.vertical ? len : 3)
            depth: 1
            sunken: !root.rightSide
        }
    }

    // geriffelte Griffleiste in einer flachen Mulde
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
            bottomMargin: root.vertical ? 1 : root.pad
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
            // Rillen: dunkle Linie mit heller Linie darunter, dazwischen eine Zeile Grund
            for (let p = 0; p + 1 < (root.vertical ? w : h); p += 3) {
                ctx.fillStyle = root.darkColor;
                root.vertical ? ctx.fillRect(p, 0, 1, h) : ctx.fillRect(0, p, w, 1);
                ctx.fillStyle = root.lightColor;
                root.vertical ? ctx.fillRect(p + 1, 0, 1, h) : ctx.fillRect(0, p + 1, w, 1);
            }
        }
    }
}
