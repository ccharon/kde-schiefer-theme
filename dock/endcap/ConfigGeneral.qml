// Schiefer end piece: settings
// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property string cfg_side

    Kirigami.FormLayout {
        QQC2.RadioButton {
            Kirigami.FormData.label: i18n("Side:")
            text: i18n("Left (button with bar)")
            checked: cfg_side !== "right"
            onToggled: if (checked) cfg_side = "left"
        }
        QQC2.RadioButton {
            text: i18n("Right (button with square)")
            checked: cfg_side === "right"
            onToggled: if (checked) cfg_side = "right"
        }
    }
}
