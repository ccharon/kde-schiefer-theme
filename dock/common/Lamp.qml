/*
 * Schiefer: indicator lamp of a monitored CDE subpanel control (dtwm UI.c, the "indicator"
 * left of the control; image FpindcY: a 3 px wide yellow bar). Lit when on, nothing when off.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick

Rectangle {
    property bool on: false
    width: 3
    color: "#ffd700"
    visible: on
}
