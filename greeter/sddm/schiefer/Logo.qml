/*
 * Picture panel on the right of the login dialog, like the vendor logo of dtlogin: sunken, in
 * the dialog color, with the three slate plates of the emblem in the middle (no tile, no text).
 * theme.conf "logo" puts an image there instead.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import "kit"

Bevel {
    id: logo
    required property Pal pal
    property string image
    base: pal.bg
    sunken: true
    implicitWidth: 13 * pal.u

    readonly property int inner: Math.min(width, height) - 2 * depth - 2 * Math.round(pal.u * 0.8)

    Image {
        visible: logo.image !== ""
        source: logo.image !== "" ? Qt.resolvedUrl(logo.image) : ""
        anchors.fill: parent
        anchors.margins: logo.depth + Math.round(logo.pal.u * 0.8)
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
    Emblem {
        visible: logo.image === ""
        pal: logo.pal
        tile: false
        anchors.centerIn: parent
        width: Math.min(logo.inner, 10 * logo.pal.u)
        height: width
    }
}
