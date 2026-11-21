/*
 * Ein Eintrag der Icon Box in der Listenansicht (Icon-Manager wie bei twm/FvwmIconMan):
 * Symbol links, Titel und Programm rechts daneben. Zustand über das Motif-Relief:
 *   offen = erhaben, aktiv = eingedrückt + Hervorhebung, minimiert = flach + kursiv,
 *   will Aufmerksamkeit = orange getönt.
 * Gruppen (mehrere Fenster einer Anwendung) zeigen Programm, Anzahl und einen Pfeil;
 * ein Klick klappt seitlich eine Schublade mit den einzelnen Fenstern auf.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

Item {
    id: row

    required property var tasksModel
    required property var modelIndex     // QModelIndex dieses Eintrags
    required property var model          // Rollen des TasksModel
    required property var box            // PlasmoidItem (openGroup, closeGroup, desktopInfo)
    property bool inGroupPopup: false
    property bool groupOpen: false

    readonly property bool isGroup: model?.IsGroupParent === true
    readonly property bool active: model?.IsActive === true
    readonly property bool minimized: model?.IsMinimized === true
    readonly property bool starting: model?.IsStartup === true
    readonly property bool attention: model?.IsDemandingAttention === true
    readonly property int childCount: model?.ChildCount ?? 0
    readonly property string appName: model?.AppName || ""
    readonly property string title: isGroup ? (appName || (model?.display ?? "")) : (model?.display ?? "")
    // zweite Zeile: Programm; bei Gruppen die Anzahl, in der Gruppen-Schublade nichts
    readonly property string subtitle: isGroup ? i18np("%1 Fenster", "%1 Fenster", childCount)
                                     : inGroupPopup ? "" : (appName !== title ? appName : "")
    readonly property bool pressed: mouse.pressed && mouse.containsMouse
    readonly property bool sunken: active || pressed || groupOpen
    readonly property color base: attention ? Qt.tint(Kirigami.Theme.backgroundColor, Qt.rgba(0.85, 0.6, 0.2, 0.45))
                                            : Kirigami.Theme.backgroundColor

    implicitHeight: Kirigami.Units.iconSizes.medium + 2 * Kirigami.Units.smallSpacing + 4

    Bevel {
        anchors.fill: parent
        // minimiert: flach, nur beim Überfahren eine feine Kante
        visible: !row.minimized || row.sunken || mouse.containsMouse
        depth: row.minimized && !row.sunken ? 1 : 2
        sunken: row.sunken
        base: row.base
        fill: row.active ? Kirigami.Theme.highlightColor
            : mouse.containsMouse ? Scheme.hoverColor(row.base) : row.base
        filled: !row.minimized || row.sunken || mouse.containsMouse || row.attention
    }

    RowLayout {
        anchors.fill: parent
        anchors.rightMargin: Kirigami.Units.smallSpacing + 2
        // eingedrückt: Inhalt 1 px nach unten rechts, wie im Qt-Stil
        anchors.topMargin: row.sunken ? 1 : 0
        anchors.leftMargin: row.sunken ? Kirigami.Units.smallSpacing + 3 : Kirigami.Units.smallSpacing + 2
        spacing: Kirigami.Units.smallSpacing + 2

        Kirigami.Icon {
            id: icon
            Layout.preferredWidth: row.inGroupPopup ? Kirigami.Units.iconSizes.smallMedium : Kirigami.Units.iconSizes.medium
            Layout.preferredHeight: Layout.preferredWidth
            source: row.model?.decoration
            active: mouse.containsMouse
            opacity: row.minimized ? 0.55 : 1
            RotationAnimator on rotation {
                running: row.starting
                from: 0; to: 360; duration: 1600; loops: Animation.Infinite
                onRunningChanged: if (!running) icon.rotation = 0
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: row.title
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.italic: row.minimized
                color: row.active ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
            }
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                visible: text.length > 0
                text: row.subtitle
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font: Kirigami.Theme.smallFont
                color: row.active ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                opacity: 0.7
            }
        }
        // Gruppen: Pfeil vom Rand weg (Schublade klappt seitlich auf)
        MotifArrow {
            visible: row.isGroup
            Layout.preferredWidth: 11
            Layout.preferredHeight: 6
            Layout.alignment: Qt.AlignVCenter
            up: Plasmoid.location !== PlasmaCore.Types.TopEdge
            rotation: Plasmoid.location === PlasmaCore.Types.LeftEdge ? 90
                    : Plasmoid.location === PlasmaCore.Types.RightEdge ? -90 : 0
            sunken: row.groupOpen
            base: row.active ? Kirigami.Theme.highlightColor : row.base
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton) {
                row.box.showMenu(row.tasksModel, row.modelIndex, row);
            } else if (row.isGroup) {
                if (event.button === Qt.MiddleButton) row.tasksModel.requestNewInstance(row.modelIndex);
                else row.box.toggleGroup(row.tasksModel, row.modelIndex, row);
            } else if (event.button === Qt.MiddleButton) {
                row.tasksModel.requestToggleMinimized(row.modelIndex);
            } else if (row.active && !row.minimized) {
                row.tasksModel.requestToggleMinimized(row.modelIndex);
            } else {
                row.tasksModel.requestActivate(row.modelIndex);
                if (row.inGroupPopup) row.box.closeGroup();
            }
        }
    }

    Timer {
        interval: 2500
        running: row.isGroup && !row.inGroupPopup && row.box.testGroup.length > 0 && row.box.testGroup === row.appName
        onTriggered: row.box.toggleGroup(row.tasksModel, row.modelIndex, row)
    }

    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        active: !row.isGroup && !row.groupOpen
        mainText: row.model?.display ?? ""
        subText: {
            const parts = [];
            if (row.appName && row.appName !== row.model?.display) parts.push(row.appName);
            if (row.minimized) parts.push(i18n("minimiert"));
            return parts.join(" – ");
        }
        icon: row.model?.decoration
        location: Plasmoid.location
    }
}
