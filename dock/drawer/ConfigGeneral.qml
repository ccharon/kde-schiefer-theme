// Schiefer-Schublade – Einstellungen
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
            Kirigami.FormData.label: i18n("Im Panel zeigen:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("Symbol des Hauptprogramms"), value: "launcher" },
                { text: i18n("Digitaluhr"), value: "clock" },
                { text: i18n("Kalenderblatt"), value: "date" },
                { text: i18n("Systemabschnitt (Statussymbole)"), value: "system" },
                { text: i18n("Ordner (Inhalt in der Schublade)"), value: "folder" }
            ]
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(cfg_face))
            onActivated: cfg_face = currentValue
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Ordner:")
            visible: cfg_face === "folder"
            QQC2.TextField {
                id: folderField
                Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                placeholderText: i18n("z. B. ~/Schreibtisch")
            }
            QQC2.Button {
                icon.name: "document-open-folder"
                text: i18n("Wählen …")
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
            text: i18n("Plasma-Systemabschnitt im selben Panel ausblenden")
        }
        QQC2.TextField {
            id: title
            Kirigami.FormData.label: i18n("Titel der Schublade:")
            placeholderText: i18n("Name des Hauptprogramms")
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            opacity: 0.75
            text: i18n("Programme aus dem Startmenü auf die Lasche oder in die geöffnete Schublade ziehen. Rechtsklick auf einen Eintrag macht ihn zum Hauptsymbol. Bei Uhr und Kalenderblatt startet ein Klick das Hauptprogramm, falls eines gesetzt ist (z. B. Merkuro), sonst öffnet er die Schublade. Der Systemabschnitt braucht einen Plasma-Systemabschnitt im selben Panel; er zeigt dessen aktive Symbole und listet in der Schublade alle Einträge.")
        }
    }
}
