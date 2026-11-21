// Schiefer console: settings
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
    property alias cfg_desktopColorsFromScheme: fromScheme.checked
    property var cfg_desktopColors
    property var cfg_desktopColorsDefault

    Kirigami.FormLayout {
        QQC2.SpinBox { id: rows; Kirigami.FormData.label: i18n("Rows:"); from: 1; to: 4 }
        QQC2.SpinBox { id: deskWidth; Kirigami.FormData.label: i18n("Desktop button width (grid units):"); from: 3; to: 20 }
        QQC2.SpinBox { id: taskWidth; Kirigami.FormData.label: i18n("Window button width (grid units):"); from: 4; to: 30 }
        QQC2.SpinBox { id: minCols; Kirigami.FormData.label: i18n("Minimum window columns:"); from: 0; to: 12 }
        QQC2.SpinBox { id: minTaskWidth; Kirigami.FormData.label: i18n("Minimum window button width (grid units):"); from: 2; to: 30 }
        QQC2.SpinBox {
            id: maxCols
            Kirigami.FormData.label: i18n("Maximum window columns:")
            from: 0; to: 40
            textFromValue: v => v === 0 ? i18n("as many as fit") : String(v)
        }
        QQC2.CheckBox { id: showTasks; Kirigami.FormData.label: i18n("Windows:"); text: i18n("Show window buttons (otherwise use the icon box)") }
        QQC2.CheckBox { id: onlyCurrent; enabled: showTasks.checked; text: i18n("Only from the current desktop") }
        QQC2.CheckBox { id: lock; Kirigami.FormData.label: i18n("Buttons:"); text: i18n("Lock") }
        QQC2.CheckBox { id: exit; text: i18n("Launch lamp and EXIT") }
        QQC2.CheckBox { id: fromScheme; Kirigami.FormData.label: i18n("Colors:"); text: i18n("Take from the color scheme") }
        QQC2.TextField {
            Kirigami.FormData.label: i18n("Custom desktop colors:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
            text: (cfg_desktopColors || []).join(", ")
            onEditingFinished: cfg_desktopColors = text.split(",").map(s => s.trim()).filter(s => s.length)
        }
    }
}
