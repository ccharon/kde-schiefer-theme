// Schiefer status tiles: settings
// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_hideTray: hideTray.checked
    property alias cfg_iconScale: iconScale.value
    property alias cfg_maxTiles: maxTiles.value

    Kirigami.FormLayout {
        QQC2.CheckBox { id: hideTray; Kirigami.FormData.label: i18n("System tray:"); text: i18n("Hide the Plasma system tray in the same panel") }
        QQC2.SpinBox {
            id: maxTiles
            Kirigami.FormData.label: i18n("Maximum tiles:")
            from: 0; to: 30
            textFromValue: v => v === 0 ? i18n("all active") : String(v)
            valueFromText: t => { const n = parseInt(t); return isNaN(n) ? 0 : n; }
        }
        QQC2.SpinBox { id: iconScale; Kirigami.FormData.label: i18n("Icon size (% of the tile):"); from: 30; to: 90; stepSize: 5 }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            opacity: 0.75
            text: i18n("The tiles show the entries of a Plasma system tray, which must be in the same panel. Which entries appear as tiles and which in the list behind the arrow is set in its settings (right click on the arrow tile). If there are more active entries than tiles, the rest move to the top of the list.")
        }
    }
}
