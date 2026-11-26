/*
 * Small raised lamp that marks a launcher whose program already runs
 * (a click then brings it forward instead of starting it again).
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.kirigami as Kirigami

Bevel {
    width: 7
    height: 7
    depth: 1
    base: Kirigami.Theme.highlightColor
}
