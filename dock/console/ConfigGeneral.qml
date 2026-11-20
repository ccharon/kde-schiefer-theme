// Schiefer-Konsole – Einstellungen
// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_rows: rows.value
    property alias cfg_desktopButtonWidth: deskWidth.value
    property alias cfg_taskButtonWidth: taskWidth.value
    property alias cfg_minTaskColumns: minCols.value
    property alias cfg_maxTaskColumns: maxCols.value
    property alias cfg_minTaskButtonWidth: minTaskWidth.value
    property alias cfg_showLockButton: lock.checked
    property alias cfg_showExitButton: exit.checked
    property alias cfg_onlyCurrentDesktop: onlyCurrent.checked
    property alias cfg_showTasks: showTasks.checked
    property var cfg_desktopColors
    property var cfg_desktopColorsDefault

    Kirigami.FormLayout {
        QQC2.SpinBox { id: rows; Kirigami.FormData.label: i18n("Zeilen:"); from: 1; to: 4 }
        QQC2.SpinBox { id: deskWidth; Kirigami.FormData.label: i18n("Breite Arbeitsflächen-Knopf (Rastereinheiten):"); from: 3; to: 20 }
        QQC2.SpinBox { id: taskWidth; Kirigami.FormData.label: i18n("Breite Fensterknopf (Rastereinheiten):"); from: 4; to: 30 }
        QQC2.SpinBox { id: minCols; Kirigami.FormData.label: i18n("Fensterspalten mindestens:"); from: 0; to: 12 }
        QQC2.SpinBox { id: minTaskWidth; Kirigami.FormData.label: i18n("Fensterknopf mindestens (Rastereinheiten):"); from: 2; to: 30 }
        QQC2.SpinBox {
            id: maxCols
            Kirigami.FormData.label: i18n("Fensterspalten höchstens:")
            from: 0; to: 40
            textFromValue: v => v === 0 ? i18n("so viele, wie passen") : String(v)
        }
        QQC2.CheckBox { id: showTasks; Kirigami.FormData.label: i18n("Fenster:"); text: i18n("Fensterknöpfe zeigen (sonst Icon Box nutzen)") }
        QQC2.CheckBox { id: onlyCurrent; enabled: showTasks.checked; text: i18n("Nur von der aktuellen Arbeitsfläche") }
        QQC2.CheckBox { id: lock; Kirigami.FormData.label: i18n("Knöpfe:"); text: i18n("Sperren") }
        QQC2.CheckBox { id: exit; text: i18n("Startlampe und EXIT") }
        QQC2.TextField {
            Kirigami.FormData.label: i18n("Farben der Arbeitsflächen:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
            text: (cfg_desktopColors || []).join(", ")
            onEditingFinished: cfg_desktopColors = text.split(",").map(s => s.trim()).filter(s => s.length)
        }
    }
}
