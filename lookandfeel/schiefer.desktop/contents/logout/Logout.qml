/*
 * Schiefer: log out / restart / shut down as a Motif dialog with a title bar.
 * The screen behind it is covered with a 50 % dot pattern (the way X11 grays out unavailable things).
 * Signals and context (sdtype, maysd, spdMethods ...) as in the Breeze theme, or ksmserver does not connect.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons
import org.kde.plasma.private.sessions
import "../kit"
import "../kit/T.js" as T
import "timer.js" as AutoTriggerTimer

Item {
    id: root
    height: screenGeometry.height
    width: screenGeometry.width

    signal logoutRequested()
    signal haltRequested()
    signal haltUpdateRequested()
    signal suspendRequested(int spdMethod)
    signal rebootRequested()
    signal rebootRequested2(int opt)
    signal rebootUpdateRequested()
    signal cancelRequested()
    signal lockScreenRequested()
    signal cancelSoftwareUpdateRequested()

    property real timeout: 30
    property real remainingTime: root.timeout
    readonly property bool showAllOptions: sdtype === ShutdownType.ShutdownTypeDefault

    property var currentAction: {
        switch (sdtype) {
        case ShutdownType.ShutdownTypeReboot:
            return () => softwareUpdatePending ? rebootUpdateRequested() : rebootRequested();
        case ShutdownType.ShutdownTypeHalt:
            return () => softwareUpdatePending ? haltUpdateRequested() : haltRequested();
        default:
            return () => logoutRequested();
        }
    }
    onRemainingTimeChanged: if (remainingTime <= 0) (currentAction)()

    Timer {
        id: countDownTimer
        running: !root.showAllOptions
        repeat: true
        interval: 1000
        onTriggered: root.remainingTime--
        Component.onCompleted: AutoTriggerTimer.addCancelAutoTriggerCallback(() => { countDownTimer.running = false; })
    }

    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    Kirigami.Theme.inherit: false
    Item { id: viewSet; Kirigami.Theme.colorSet: Kirigami.Theme.View; Kirigami.Theme.inherit: false }
    Pal {
        id: pal
        bg: Kirigami.Theme.backgroundColor
        fg: Kirigami.Theme.textColor
        field: viewSet.Kirigami.Theme.backgroundColor
        active: Kirigami.Theme.highlightColor
        activeText: Kirigami.Theme.highlightedTextColor
        alert: Kirigami.Theme.negativeTextColor
        baseFont: Kirigami.Theme.defaultFont
    }
    KCoreAddons.KUser { id: kuser }
    SessionsModel { id: otherSessions; includeUnusedSessions: false; includeOwnSession: false }

    // 50 % dot pattern over the screen
    Image {
        anchors.fill: parent
        source: "stipple.png"
        fillMode: Image.Tile
        smooth: false
        opacity: 0.55
    }
    MouseArea { anchors.fill: parent; onClicked: root.cancelRequested() }

    readonly property string actionText: {
        switch (sdtype) {
        case ShutdownType.ShutdownTypeReboot: return T.t("Neu starten", "Restart");
        case ShutdownType.ShutdownTypeHalt: return T.t("Herunterfahren", "Shut Down");
        case ShutdownType.ShutdownTypeNone: return T.t("Abmelden", "Log Out");
        default: return T.t("Sitzung beenden", "End Session");
        }
    }

    Panel {
        id: dialog
        pal: pal
        title: root.actionText + " – " + kuser.host
        anchors.centerIn: parent
        MouseArea { anchors.fill: parent; onPressed: AutoTriggerTimer.cancelAutoTrigger() }

        ColumnLayout {
            width: Math.max(implicitWidth, 30 * pal.u)
            spacing: pal.u

            RowLayout {
                spacing: pal.u
                Layout.fillWidth: true
                // Motif-Dialogsymbol links
                Kirigami.Icon {
                    source: sdtype === ShutdownType.ShutdownTypeReboot ? "system-reboot"
                          : sdtype === ShutdownType.ShutdownTypeHalt ? "system-shutdown"
                          : sdtype === ShutdownType.ShutdownTypeNone ? "system-log-out" : "system-shutdown"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.large
                    Layout.preferredHeight: Kirigami.Units.iconSizes.large
                    Layout.alignment: Qt.AlignTop
                }
                ColumnLayout {
                    spacing: Math.round(pal.u / 3)
                    Layout.fillWidth: true
                    Text {
                        renderType: pal.renderType
                        font.family: pal.font.family
                        font.pixelSize: Math.round(pal.u * 1.1)
                        font.bold: true
                        color: pal.fg
                        text: root.showAllOptions
                            ? T.t("Sitzung von %1 auf %2 beenden?", "End the session of %1 on %2?").arg(kuser.loginName).arg(kuser.host)
                            : T.t("%1?", "%1?").arg(root.actionText)
                    }
                    Text {
                        renderType: pal.renderType
                        visible: countDownTimer.running
                        font: pal.font
                        color: pal.fg
                        text: {
                            const n = root.remainingTime;
                            switch (sdtype) {
                            case ShutdownType.ShutdownTypeReboot: return T.t("Neustart in %1 s", "Restarting in %1 s").arg(n);
                            case ShutdownType.ShutdownTypeHalt: return T.t("Herunterfahren in %1 s", "Shutting down in %1 s").arg(n);
                            default: return T.t("Abmeldung in %1 s", "Logging out in %1 s").arg(n);
                            }
                        }
                    }
                    Text {
                        renderType: pal.renderType
                        visible: otherSessions.count > 0 && (sdtype !== ShutdownType.ShutdownTypeNone || root.showAllOptions)
                        font: pal.font
                        color: pal.alert
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        text: T.t("Weitere Benutzer sind angemeldet (%1). Beim Herunterfahren oder Neustart können sie Daten verlieren.",
                                  "Other users are logged in (%1). They may lose work if the computer shuts down or restarts.").arg(otherSessions.count)
                    }
                    Text {
                        renderType: pal.renderType
                        visible: softwareUpdatePending
                        font.family: pal.font.family
                        font.pointSize: pal.font.pointSize
                        font.italic: true
                        color: pal.fg
                        text: T.t("Aktualisierungen werden dabei installiert.", "Updates will be installed.")
                    }
                    Text {
                        renderType: pal.renderType
                        visible: rebootToFirmwareSetup || rebootToBootLoaderMenu || rebootToBootLoaderEntry != ""
                        font.family: pal.font.family
                        font.pointSize: pal.font.pointSize
                        font.italic: true
                        color: pal.fg
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        text: rebootToFirmwareSetup ? T.t("Neustart in die Firmware-Einstellungen.", "Restart into firmware setup.")
                            : rebootToBootLoaderMenu ? T.t("Neustart ins Bootmenü.", "Restart into the boot loader menu.")
                            : T.t("Neustart nach %1.", "Restart into %1.").arg(rebootToBootLoaderEntry)
                    }
                }
            }
            Etch { base: pal.bg; Layout.fillWidth: true }

            // button row as in a Motif dialog: equal widths, default button with a ring
            RowLayout {
                id: buttons
                spacing: Math.round(pal.u / 2)
                Layout.fillWidth: true
                uniformCellSizes: true
                MButton { id: bLogout; pal: pal; text: T.t("&Abmelden", "&Log Out"); Layout.fillWidth: true
                    visible: canLogout && (sdtype === ShutdownType.ShutdownTypeNone || root.showAllOptions)
                    isDefault: sdtype === ShutdownType.ShutdownTypeNone || root.showAllOptions
                    onClicked: root.logoutRequested() }
                MButton { id: bReboot; pal: pal; Layout.fillWidth: true
                    text: softwareUpdatePending ? T.t("Aktualisieren + &Neustart", "Update + &Restart") : T.t("&Neu starten", "&Restart")
                    visible: maysd && (sdtype === ShutdownType.ShutdownTypeReboot || root.showAllOptions)
                    isDefault: sdtype === ShutdownType.ShutdownTypeReboot
                    onClicked: softwareUpdatePending ? root.rebootUpdateRequested() : root.rebootRequested() }
                MButton { id: bHalt; pal: pal; Layout.fillWidth: true
                    text: softwareUpdatePending ? T.t("Aktualisieren + &Aus", "Update + Shut &Down") : T.t("&Herunterfahren", "Shut &Down")
                    visible: maysd && (sdtype === ShutdownType.ShutdownTypeHalt || root.showAllOptions)
                    isDefault: sdtype === ShutdownType.ShutdownTypeHalt
                    onClicked: softwareUpdatePending ? root.haltUpdateRequested() : root.haltRequested() }
                MButton { id: bSleep; pal: pal; text: T.t("&Bereitschaft", "Slee&p"); Layout.fillWidth: true
                    visible: spdMethods.SuspendState && root.showAllOptions
                    onClicked: root.suspendRequested(2) }
                MButton { id: bHib; pal: pal; text: T.t("&Ruhezustand", "H&ibernate"); Layout.fillWidth: true
                    visible: spdMethods.HibernateState && root.showAllOptions
                    onClicked: root.suspendRequested(4) }
                MButton { id: bCancel; pal: pal; text: T.t("Abbre&chen", "&Cancel"); Layout.fillWidth: true
                    onClicked: root.cancelRequested() }
            }
        }
    }

    readonly property var buttonList: [bLogout, bReboot, bHalt, bSleep, bHib, bCancel]
    function visibleButtons() { return buttonList.filter(b => b.visible); }
    function move(d) {
        const v = visibleButtons();
        let i = v.findIndex(b => b.activeFocus);
        if (i < 0) i = v.findIndex(b => b.isDefault);
        v[(i + d + v.length) % v.length].forceActiveFocus();
    }

    focus: true
    Component.onCompleted: {
        const d = visibleButtons().find(b => b.isDefault) || bCancel;
        d.forceActiveFocus();
    }
    Keys.onPressed: e => {
        AutoTriggerTimer.cancelAutoTrigger();
        if (e.key === Qt.Key_Escape) { root.cancelRequested(); e.accepted = true; return; }
        if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) { move(-1); e.accepted = true; return; }
        if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) { move(1); e.accepted = true; return; }
        const c = e.text.toLowerCase();
        if (!c) return;
        // mnemonics: with or without Alt, as in Motif dialogs without a text field
        for (const b of visibleButtons()) {
            if (b.mnemonic === c) { b.clicked(); e.accepted = true; return; }
        }
    }
}
