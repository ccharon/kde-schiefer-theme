/*
    One pattern layer: tile the index tile device-exact and color it in the levels of `color`.
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

    // Actual ratio of device to logical pixels of the window. With fractional scaling (1.5)
    // Screen.devicePixelRatio on Wayland reports the integer output scale (2), which would make
    // pattern pixels alternate between 1 and 2 device pixels.
    // QQuickWindow.devicePixelRatio exists since Qt 6.11; Screen is the fallback.
    readonly property real devicePixelRatio: Window.window?.devicePixelRatio ?? Screen.devicePixelRatio

    // uniforms (names as in shaders/backdrop.frag)
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
        // unfiltered and unscaled: the shader only reads texel centers
        smooth: false
        mipmap: false
        asynchronous: false
        source: Qt.resolvedUrl("../patterns/" + (Palette.indexOf(effect.pattern) >= 0 ? effect.pattern : "flach") + ".png")
    }
}
