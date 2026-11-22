// Renders the emblem of the login screens (greeter/kit/Emblem.qml) as PNG for the boot screen.
// qml6 -platform offscreen plymouth/render_emblem.qml -- <out.png> <size>
import QtQuick
import "../greeter/kit"

Item {
    id: root
    readonly property var args: Qt.application.arguments.slice(Qt.application.arguments.indexOf("--") + 1)
    width: Number(args[1]); height: width
    Pal { id: pal }
    Emblem { id: em; pal: pal; anchors.fill: parent }
    Timer {
        interval: 300; running: true
        onTriggered: root.grabToImage(r => { r.saveToFile(root.args[0]); Qt.quit(); })
    }
}
