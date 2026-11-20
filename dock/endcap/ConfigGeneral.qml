// Schiefer-Abschluss – Einstellungen
// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property string cfg_side

    Kirigami.FormLayout {
        QQC2.RadioButton {
            Kirigami.FormData.label: i18n("Seite:")
            text: i18n("Links (Knopf mit Strich)")
            checked: cfg_side !== "right"
            onToggled: if (checked) cfg_side = "left"
        }
        QQC2.RadioButton {
            text: i18n("Rechts (Knopf mit Quadrat)")
            checked: cfg_side === "right"
            onToggled: if (checked) cfg_side = "right"
        }
    }
}
