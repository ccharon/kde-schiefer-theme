// Motif separator (XmSHADOW_ETCHED_IN): shadow above light
import QtQuick
import "Motif.js" as Motif

Item {
    property color base: "#bec2d3"
    readonly property var motif: Motif.colors(base)
    implicitHeight: 2
    Rectangle { width: parent.width; height: 1; color: parent.motif.bottom }
    Rectangle { y: 1; width: parent.width; height: 1; color: parent.motif.top }
}
