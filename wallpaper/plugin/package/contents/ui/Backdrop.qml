/*
    Eine Musterebene: Index-Kachel geräteexakt kacheln und in der Abstufung von `color` einfärben.
*/
import QtQuick
import QtQuick.Window
import "Palette.js" as Palette

ShaderEffect {
    id: effect

    property string pattern: "koeper"
    property color color: "#68799b"
    property real pixelScale: 1

    readonly property var ramp: Palette.ramp(color)

    // tatsächliches Verhältnis Gerätepixel/logische Pixel des Fensters. Screen.devicePixelRatio
    // meldet unter Wayland bei gebrochener Skalierung (1,5) die ganzzahlige Ausgabeskalierung (2)
    // – damit würde jeder Musterpixel abwechselnd 1 und 2 Gerätepixel breit.
    // QQuickWindow.devicePixelRatio gibt es seit Qt 6.11, sonst Screen als Ersatz.
    readonly property real devicePixelRatio: Window.window?.devicePixelRatio ?? Screen.devicePixelRatio

    // Uniforms (Namen wie in shaders/backdrop.frag)
    readonly property size deviceSize: Qt.size(Math.round(width * devicePixelRatio),
                                               Math.round(height * devicePixelRatio))
    readonly property size tileSize: Qt.size(Math.max(1, tileImage.sourceSize.width),
                                             Math.max(1, tileImage.sourceSize.height))
    readonly property var tile: tileImage
    readonly property color c0: ramp[0]
    readonly property color c1: ramp[1]
    readonly property color c2: ramp[2]
    readonly property color c3: ramp[3]
    readonly property color c4: ramp[4]
    readonly property color c5: ramp[5]

    fragmentShader: Qt.resolvedUrl("../shaders/backdrop.frag.qsb")

    Image {
        id: tileImage
        visible: false
        // ungefiltert, nicht skaliert: der Shader liest ohnehin nur Texelmitten
        smooth: false
        mipmap: false
        asynchronous: false
        source: Qt.resolvedUrl("../patterns/" + (Palette.indexOf(effect.pattern) >= 0 ? effect.pattern : "flach") + ".png")
    }
}
