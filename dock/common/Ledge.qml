/*
 * Ledge at the bottom of the front panel as in CDE: dark line, two rows of panel surface,
 * two rows of shadow. Placed by DockRow; it reaches beyond the applet into the gaps.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: ledge

    required property DockRow row

    readonly property color base: Kirigami.Theme.backgroundColor
    readonly property color dark: Scheme.motifColors(base).bottom

    visible: row.ledge
    x: -row.ledgeLeft
    y: row.ledgeY
    width: row.target.width + row.ledgeLeft + row.ledgeRight
    height: row.ledgeHeight

    Rectangle { y: 0; width: parent.width; height: 1; color: ledge.dark }
    Rectangle { y: 1; width: parent.width; height: 2; color: ledge.base }
    Rectangle { y: 3; width: parent.width; height: 2; color: ledge.dark }
}
