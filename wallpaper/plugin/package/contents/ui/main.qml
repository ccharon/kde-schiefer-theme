/*
    Schiefer patterns: pixel-exact tiled retro patterns as a Plasma wallpaper.
    As in CDE each desktop can have its own pattern and color,
    so you see at once where you are. Plasma has no per-desktop wallpapers,
    so the plugin tracks the current desktop itself (TaskManager.VirtualDesktopInfo).
*/
import QtQuick
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager
import "Palette.js" as Palette

WallpaperItem {
    id: root

    readonly property var cfg: root.configuration

    TaskManager.VirtualDesktopInfo { id: desktopInfo }

    readonly property int desktopIndex: Math.max(0, desktopInfo.desktopIds.indexOf(desktopInfo.currentDesktop))
    readonly property string wantedPattern: cfg.PerDesktop
        ? Palette.pick(Palette.parseList(cfg.DesktopPatterns), desktopIndex, cfg.Pattern) : cfg.Pattern
    readonly property string wantedColor: cfg.PerDesktop
        ? Palette.pick(Palette.parseList(cfg.DesktopColors), desktopIndex, cfg.Color) : cfg.Color
    // pattern pixels in device pixels; integer magnification when scaled (like wallpaper/apply.sh),
    // never stretched: at 1.5 one pattern pixel becomes 2x2 device pixels
    readonly property int pixelScale: cfg.PixelScale > 0 ? cfg.PixelScale
                                                         : Math.max(1, Math.round(front.devicePixelRatio))

    onWantedPatternChanged: Qt.callLater(show)
    onWantedColorChanged: Qt.callLater(show)
    Component.onCompleted: show()

    function show() {
        const c = Palette.toColor(wantedColor, Palette.toColor(cfg.Color, "#68799b"));
        if (front.pattern === wantedPattern && Qt.colorEqual(front.color, c))
            return;
        if (cfg.Crossfade && front.visible && root.visible) {
            back.pattern = front.pattern;
            back.color = front.color;
            front.opacity = 0;
            front.pattern = wantedPattern;
            front.color = c;
            fade.restart();
        } else {
            fade.stop();
            front.opacity = 1;
            front.pattern = wantedPattern;
            front.color = c;
        }
    }

    Backdrop {
        id: back
        anchors.fill: parent
        pixelScale: root.pixelScale
        visible: fade.running
    }
    Backdrop {
        id: front
        anchors.fill: parent
        pixelScale: root.pixelScale
        pattern: ""
    }
    NumberAnimation {
        id: fade
        target: front
        property: "opacity"
        from: 0
        to: 1
        duration: root.cfg.CrossfadeDuration
    }
}
