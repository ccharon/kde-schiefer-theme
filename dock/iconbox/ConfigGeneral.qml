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
    property alias cfg_desktopColorsFromScheme: fromScheme.checked
    property var cfg_desktopColors
    property var cfg_desktopColorsDefault

    Kirigami.FormLayout {
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Display:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("List (icon manager like twm)"), value: "list" },
                { text: i18n("Icons (icon box like mwm)"), value: "icons" }
            ]
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(cfg_display))
            onActivated: cfg_display = currentValue
        }
        QQC2.CheckBox { id: onlyCurrent; Kirigami.FormData.label: i18n("Windows:"); text: i18n("Only from the current desktop") }
        QQC2.CheckBox { id: showNormal; text: i18n("Also show open windows (otherwise only minimized ones)") }
        QQC2.CheckBox { id: groupWindows; text: i18n("Group windows of an application") }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Order:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("As opened"), value: "opening" },
                { text: i18n("By application"), value: "app" },
                { text: i18n("Most recently used first"), value: "lastActivated" }
            ]
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(cfg_sortMode))
            onActivated: cfg_sortMode = currentValue
        }
        QQC2.SpinBox { id: columns; Kirigami.FormData.label: i18n("Columns:"); from: 1; to: 4 }
        QQC2.CheckBox { id: fromScheme; Kirigami.FormData.label: i18n("Colors:"); text: i18n("Take from the color scheme") }
        QQC2.TextField {
            Kirigami.FormData.label: i18n("Custom desktop colors:")
            enabled: !onlyCurrent.checked
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
            text: (cfg_desktopColors || []).join(", ")
            onEditingFinished: cfg_desktopColors = text.split(",").map(s => s.trim()).filter(s => s.length)
        }
        QQC2.CheckBox { id: showTitle; Kirigami.FormData.label: i18n("Header:"); text: i18n("Show \"Windows\"") }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            opacity: 0.75
            text: i18n("A click raises or restores a window; a click on the active window minimizes it. A click on a group opens its windows to the side. Middle click minimizes, right click opens the window menu. To keep windows clear of the box, set the panel to \"Dodge Windows\".")
        }
    }
}
