// Schiefer-Statuskacheln – Einstellungen
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
        QQC2.CheckBox { id: hideTray; Kirigami.FormData.label: i18n("Systemabschnitt:"); text: i18n("Plasma-Systemabschnitt im selben Panel ausblenden") }
        QQC2.SpinBox {
            id: maxTiles
            Kirigami.FormData.label: i18n("Kacheln höchstens:")
            from: 0; to: 30
            textFromValue: v => v === 0 ? i18n("alle aktiven") : String(v)
            valueFromText: t => { const n = parseInt(t); return isNaN(n) ? 0 : n; }
        }
        QQC2.SpinBox { id: iconScale; Kirigami.FormData.label: i18n("Symbolgröße (% der Kachel):"); from: 30; to: 90; stepSize: 5 }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            opacity: 0.75
            text: i18n("Die Kacheln zeigen die Einträge eines Plasma-Systemabschnitts, der im selben Panel stecken muss. Welche Einträge als Kachel erscheinen und welche in der Liste hinter dem Pfeil, legt man in dessen Einstellungen fest (Rechtsklick auf die Pfeilkachel). Gibt es mehr aktive Einträge als Kacheln, rutschen die übrigen oben in die Liste.")
        }
    }
}
