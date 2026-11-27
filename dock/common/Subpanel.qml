/*
 * Schiefer: CDE subpanel chrome (dtwm UI.c, CreateSubpanel), used by the drawers and the list
 * of the status tiles: thin raised window frame, dtwm title bar with window menu button in
 * the active title color, raised form with the 5 px offset of the subpanel form.
 * The caller puts its content in as the default property, sized by contentWidth/contentHeight
 * (the content fills the inner area: anchors.fill: parent).
 * The window menu button sends closeRequested.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

Item {
    id: sub

    property string title
    property int contentWidth: 0
    property int contentHeight: 0
    default property alias content: holder.data
    signal closeRequested()

    // outer frame 1 px, form bevel 1 px, then the 5 px offset of the subpanel form
    readonly property int frameWidth: 1
    readonly property int bodyPad: 5
    readonly property color titleColor: Scheme.activeTitle.valid ? Scheme.activeTitle : Kirigami.Theme.highlightColor
    readonly property color titleTextColor: Scheme.activeTitleText.valid ? Scheme.activeTitleText : Kirigami.Theme.highlightedTextColor

    implicitWidth: contentWidth + 2 * (frameWidth + 1 + bodyPad)
    implicitHeight: titleBar.height + contentHeight + 2 * frameWidth + 2 * (1 + bodyPad)
    width: implicitWidth
    height: implicitHeight

    // thin raised window frame like dtwm around a subpanel
    Bevel {
        anchors.fill: parent
        depth: sub.frameWidth
    }

    // dtwm title bar: window menu button, title
    Item {
        id: titleBar
        x: sub.frameWidth
        y: sub.frameWidth
        width: parent.width - 2 * sub.frameWidth
        height: titleLabel.implicitHeight + 4

        Item {
            id: menuButton
            width: parent.height
            height: parent.height
            Bevel {
                anchors.fill: parent
                depth: 1
                sunken: menuMouse.pressed && menuMouse.containsMouse
                base: sub.titleColor
            }
            // the bar of the Motif window menu button
            Bevel {
                anchors.centerIn: parent
                width: Math.round(parent.width * 0.55)
                height: 3
                depth: 1
                base: sub.titleColor
            }
            MouseArea {
                id: menuMouse
                anchors.fill: parent
                onClicked: sub.closeRequested()
            }
        }
        Item {
            anchors { left: menuButton.right; right: parent.right; top: parent.top; bottom: parent.bottom }
            Bevel { anchors.fill: parent; depth: 1; base: sub.titleColor }
            PlasmaComponents3.Label {
                id: titleLabel
                anchors.centerIn: parent
                width: parent.width - 2 * Kirigami.Units.smallSpacing
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: sub.title
                color: sub.titleTextColor
            }
        }
    }

    // subpanel form
    Bevel {
        id: body
        anchors { left: parent.left; right: parent.right; top: titleBar.bottom; bottom: parent.bottom; margins: sub.frameWidth; topMargin: 0 }
        depth: 1
    }
    Item {
        id: holder
        anchors { fill: body; margins: 1 + sub.bodyPad }
    }
}
