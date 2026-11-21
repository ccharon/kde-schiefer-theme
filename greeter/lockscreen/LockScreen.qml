/*
 * Schiefer lock screen. kscreenlocker expects the properties and signals defined here.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick

Item {
    id: root
    property bool debug: false
    property string notification
    signal clearPassword()
    signal notificationRepeated()
    property bool viewVisible: false

    LayoutMirroring.enabled: Application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true
    implicitWidth: 800
    implicitHeight: 600

    SchieferLock { anchors.fill: parent }
}
