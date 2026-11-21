// Schiefer drawer: settings
// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import QtQuick.Dialogs as Dialogs

KCM.SimpleKCM {
    property string cfg_face
    property alias cfg_title: title.text
    property alias cfg_folderUrl: folderField.text
    property alias cfg_hideTray: hideTray.checked

    Kirigami.FormLayout {
        QQC2.ComboBox {
            id: face
            Kirigami.FormData.label: i18n("Show in the panel:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("Icon of the main application"), value: "launcher" },
                { text: i18n("Digital clock"), value: "clock" },
                { text: i18n("Calendar page"), value: "date" },
                { text: i18n("System tray (status icons)"), value: "system" },
                { text: i18n("Folder (contents in the drawer)"), value: "folder" }
            ]
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(cfg_face))
            onActivated: cfg_face = currentValue
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Folder:")
            visible: cfg_face === "folder"
            QQC2.TextField {
                id: folderField
                Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                placeholderText: i18n("for example ~/Desktop")
            }
            QQC2.Button {
                icon.name: "document-open-folder"
                text: i18n("Choose…")
                onClicked: folderDialog.open()
            }
            Dialogs.FolderDialog {
                id: folderDialog
                onAccepted: folderField.text = selectedFolder.toString()
            }
        }
        QQC2.CheckBox {
            id: hideTray
            visible: cfg_face === "system"
            text: i18n("Hide the Plasma system tray in the same panel")
        }
        QQC2.TextField {
            id: title
            Kirigami.FormData.label: i18n("Drawer title:")
            placeholderText: i18n("Name of the main application")
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            opacity: 0.75
            text: i18n("Drag applications from the launcher onto the tab or into the open drawer. Right click on an entry makes it the main icon. For the clock and the calendar page a click starts the main application if one is set (for example Merkuro); otherwise it opens the drawer. The system tray mode needs a Plasma system tray in the same panel; it shows its active icons and lists all entries in the drawer.")
        }
    }
}
