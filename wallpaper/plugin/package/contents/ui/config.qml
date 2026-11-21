/*
    Einstellungen des Schiefer-Hintergrunds.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls
import org.kde.taskmanager as TaskManager
import "Palette.js" as Palette

Kirigami.FormLayout {
    id: page
    twinFormLayouts: parentLayout

    // setzt Plasma beim Laden der Seite (ConfigurationContainmentAppearance.qml); fehlen sie,
    // bricht das Laden ab und Änderungen werden nicht als ungespeichert erkannt
    property var configDialog
    property var wallpaperConfiguration

    property bool cfg_PerDesktop
    property string cfg_Pattern
    property string cfg_Color
    property string cfg_DesktopPatterns
    property string cfg_DesktopColors
    property string cfg_DesktopColorsDefault
    property bool cfg_Crossfade
    property int cfg_CrossfadeDuration
    property int cfg_PixelScale

    readonly property var desktopInfo: TaskManager.VirtualDesktopInfo {}
    readonly property var patternList: Palette.parseList(cfg_DesktopPatterns)
    readonly property var colorList: Palette.parseList(cfg_DesktopColors)
    readonly property string slateBlue: "#68799b"

    component PatternBox: QQC2.ComboBox {
        property string key
        signal picked(string key)
        model: Palette.PATTERNS
        textRole: "name"
        valueRole: "key"
        currentIndex: Math.max(0, Palette.indexOf(key))
        onActivated: picked(currentValue)
    }

    QQC2.CheckBox {
        Kirigami.FormData.label: i18n("Arbeitsflächen:")
        text: i18n("Jede Arbeitsfläche mit eigenem Hintergrund")
        checked: cfg_PerDesktop
        onToggled: cfg_PerDesktop = checked
    }

    // gleich auf allen Arbeitsflächen
    PatternBox {
        visible: !cfg_PerDesktop
        Kirigami.FormData.label: i18n("Muster:")
        key: cfg_Pattern
        onPicked: k => cfg_Pattern = k
    }
    RowLayout {
        visible: !cfg_PerDesktop
        Kirigami.FormData.label: i18n("Farbe:")
        KQuickControls.ColorButton {
            showAlphaChannel: false
            dialogTitle: i18n("Grundton des Musters")
            color: Palette.toColor(cfg_Color, page.slateBlue)
            onAccepted: c => cfg_Color = c.toString()
        }
        QQC2.Button {
            text: i18n("Schieferblau")
            onClicked: cfg_Color = page.slateBlue
        }
    }

    // je Arbeitsfläche
    ColumnLayout {
        visible: cfg_PerDesktop
        Kirigami.FormData.label: i18n("Muster und Farbe:")
        Repeater {
            model: Math.max(1, page.desktopInfo.numberOfDesktops)
            delegate: RowLayout {
                required property int index
                QQC2.Label {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                    elide: Text.ElideRight
                    text: page.desktopInfo.desktopNames[index] ?? i18n("Arbeitsfläche %1", index + 1)
                }
                PatternBox {
                    key: Palette.pick(page.patternList, index, cfg_Pattern)
                    onPicked: k => cfg_DesktopPatterns = Palette.setAt(cfg_DesktopPatterns, index, k, cfg_Pattern)
                }
                KQuickControls.ColorButton {
                    showAlphaChannel: false
                    dialogTitle: i18n("Grundton für %1", page.desktopInfo.desktopNames[index] ?? index + 1)
                    color: Palette.toColor(Palette.pick(page.colorList, index, cfg_Color), page.slateBlue)
                    onAccepted: c => cfg_DesktopColors = Palette.setAt(cfg_DesktopColors, index, c.toString(), cfg_Color)
                }
            }
        }
    }
    QQC2.TextField {
        visible: cfg_PerDesktop
        Kirigami.FormData.label: i18n("Farbliste:")
        Layout.fillWidth: true
        // kommagetrennt, z. B. aus einer Palette oder aus desktopColors der Schiefer-Konsole
        placeholderText: "#8fa3bf,#bba78e,…"
        text: cfg_DesktopColors
        onEditingFinished: cfg_DesktopColors = Palette.parseList(text).join(",")
    }
    QQC2.Button {
        visible: cfg_PerDesktop
        text: i18n("Farben des Docks (Vorgabe)")
        enabled: cfg_DesktopColorsDefault.length > 0 && cfg_DesktopColors !== cfg_DesktopColorsDefault
        onClicked: cfg_DesktopColors = cfg_DesktopColorsDefault
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.CheckBox {
        Kirigami.FormData.label: i18n("Wechsel:")
        text: i18n("Kurz überblenden statt sofort umschalten")
        checked: cfg_Crossfade
        onToggled: cfg_Crossfade = checked
    }
    QQC2.ComboBox {
        Kirigami.FormData.label: i18n("Musterpixel:")
        model: [i18n("Automatisch (ganzzahlig zur Skalierung)"), "1 × 1", "2 × 2", "3 × 3", "4 × 4"]
        currentIndex: Math.min(cfg_PixelScale, 4)
        onActivated: cfg_PixelScale = currentIndex
    }
}
