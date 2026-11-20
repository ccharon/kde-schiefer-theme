// Schiefer-Icon-Box – Einstellungen
// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_onlyCurrentDesktop: onlyCurrent.checked
    property alias cfg_showNormalWindows: showNormal.checked
    property alias cfg_showTitle: showTitle.checked
    property alias cfg_columns: columns.value
    property string cfg_sortMode
    property string cfg_display
    property alias cfg_groupWindows: groupWindows.checked
    property var cfg_desktopColors
    property var cfg_desktopColorsDefault

    Kirigami.FormLayout {
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Darstellung:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("Liste (Icon-Manager wie twm)"), value: "list" },
                { text: i18n("Symbole (Icon Box wie mwm)"), value: "icons" }
            ]
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(cfg_display))
            onActivated: cfg_display = currentValue
        }
        QQC2.CheckBox { id: onlyCurrent; Kirigami.FormData.label: i18n("Fenster:"); text: i18n("Nur von der aktuellen Arbeitsfläche") }
        QQC2.CheckBox { id: showNormal; text: i18n("Auch offene Fenster zeigen (sonst nur minimierte)") }
        QQC2.CheckBox { id: groupWindows; text: i18n("Fenster einer Anwendung gruppieren") }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Reihenfolge:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("Wie geöffnet"), value: "opening" },
                { text: i18n("Nach Programm"), value: "app" },
                { text: i18n("Zuletzt benutzt zuerst"), value: "lastActivated" }
            ]
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(cfg_sortMode))
            onActivated: cfg_sortMode = currentValue
        }
        QQC2.SpinBox { id: columns; Kirigami.FormData.label: i18n("Spalten:"); from: 1; to: 4 }
        QQC2.TextField {
            Kirigami.FormData.label: i18n("Farben der Arbeitsflächen:")
            enabled: !onlyCurrent.checked
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
            text: (cfg_desktopColors || []).join(", ")
            onEditingFinished: cfg_desktopColors = text.split(",").map(s => s.trim()).filter(s => s.length)
        }
        QQC2.CheckBox { id: showTitle; Kirigami.FormData.label: i18n("Kopfzeile:"); text: i18n("„Fenster“ anzeigen") }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            opacity: 0.75
            text: i18n("Klick holt ein Fenster nach vorn oder stellt es wieder her, ein Klick auf das aktive Fenster minimiert es. Ein Klick auf eine Gruppe klappt ihre Fenster seitlich auf. Mittelklick minimiert, Rechtsklick öffnet das Fenstermenü. Damit die Box Fenstern ausweicht, die Leiste auf „Fenstern ausweichen“ stellen.")
        }
    }
}
