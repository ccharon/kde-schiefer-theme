// Startlampe wie über EXIT am Dock: versenkte Fassung, blinkt während etwas läuft
import QtQuick

Bevel {
    id: lamp
    required property Pal pal
    property bool busy: false
    property bool lit: false
    base: pal.bg
    sunken: true
    depth: 1
    implicitWidth: Math.round(pal.u * 1.4)
    implicitHeight: Math.round(pal.u * 0.6)
    fill: lit ? pal.lamp : Qt.darker(pal.bg, 1.35)
    Timer { interval: 400; repeat: true; running: lamp.busy; onTriggered: lamp.lit = !lamp.lit; onRunningChanged: lamp.lit = running }
}
