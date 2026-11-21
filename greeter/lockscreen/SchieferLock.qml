/*
 * Schiefer lock screen in the style of classic Unix workstations.
 * Idle: only the backdrop and a clock panel (seven segments as in the dock).
 * On key or mouse input: dialog panel with host name, who locked, password field,
 * Unlock / Sleep / Switch User. Logic as in the Plasma shell (LockScreenUi.qml).
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons
import org.kde.plasma.private.sessions
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.plasma.workspace.components as PW
import "kit"
import "kit/T.js" as T

Item {
    id: ui

    // colors from the color scheme (window, view, selection = active frame, complementary = front panel)
    Item { id: viewSet; Kirigami.Theme.colorSet: Kirigami.Theme.View; Kirigami.Theme.inherit: false }
    Item { id: compSet; Kirigami.Theme.colorSet: Kirigami.Theme.Complementary; Kirigami.Theme.inherit: false }
    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    Kirigami.Theme.inherit: false
    Pal {
        id: pal
        bg: Kirigami.Theme.backgroundColor
        fg: Kirigami.Theme.textColor
        field: viewSet.Kirigami.Theme.backgroundColor
        fieldText: viewSet.Kirigami.Theme.textColor
        active: Kirigami.Theme.highlightColor
        activeText: Kirigami.Theme.highlightedTextColor
        panel: compSet.Kirigami.Theme.backgroundColor
        panelText: Kirigami.Theme.textColor          // like the dock: scheme text color on the front panel (more readable than the Motif formula)
        alert: Kirigami.Theme.negativeTextColor
        baseFont: Kirigami.Theme.defaultFont
    }

    KCoreAddons.KUser { id: kuser }
    readonly property string userName: kscreenlocker_userName
    readonly property string fullName: kuser.fullName && kuser.fullName !== userName ? kuser.fullName : ""
    readonly property date lockedAt: new Date()
    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: ui.now = new Date() }

    property bool testShowDialog: false   // only for greeter/test-lock.sh
    Component.onCompleted: if (testShowDialog) screen.uiVisible = true
    property bool noPassword: false       // authenticated without input (for example RequirePassword=false)

    function handleMessage(msg) {
        if (!msg) return;
        if (!root.notification) root.notification = msg;
        else if (root.notification.includes(msg)) root.notificationRepeated();
        else root.notification += "\n" + msg;
    }

    Connections {
        target: authenticator
        function onFailed(kind) {
            if (kind != 0) return;          // non-interactive methods (fingerprint, smart card)
            ui.handleMessage(T.t("Entsperren fehlgeschlagen", "Unlocking failed"));
            graceLockTimer.restart();
            notificationRemoveTimer.restart();
            shake.restart();
        }
        function onSucceeded() {
            if (authenticator.hadPrompt) Qt.quit();
            else { ui.noPassword = true; screen.uiVisible = true; }
        }
        function onInfoMessageChanged() { ui.handleMessage(authenticator.infoMessage); }
        function onErrorMessageChanged() { ui.handleMessage(authenticator.errorMessage); }
        function onPromptChanged(msg) { ui.handleMessage(authenticator.prompt); }
        function onPromptForSecretChanged(msg) { field.grab(); }
    }

    SessionManagement { id: sessionManagement }
    Connections { target: sessionManagement; function onAboutToSuspend() { root.clearPassword(); } }
    KeyboardIndicator.KeyState { id: capsLockState; key: Qt.Key_CapsLock }

    Connections {
        target: root
        function onClearPassword() {
            field.grab();
            field.input.text = "";
            field.input.text = Qt.binding(() => PasswordSync.password);
        }
        function onNotificationRepeated() { shake.restart(); }
    }

    function unlock() {
        if (noPassword) { Qt.quit(); return; }
        if (!screen.uiVisible) return;
        okButton.forceActiveFocus();       // works around QTBUG-55460 like the Plasma shell
        authenticator.respond(field.text);
    }

    MouseArea {
        id: screen
        anchors.fill: parent
        property bool uiVisible: false
        property bool seenPositionChange: false
        readonly property bool blockUI: containsMouse && (field.text.length > 0)
        hoverEnabled: true
        cursorShape: uiVisible ? Qt.ArrowCursor : Qt.BlankCursor
        drag.filterChildren: true
        onPressed: uiVisible = true
        onPositionChanged: { uiVisible = seenPositionChange; seenPositionChange = true; }
        onUiVisibleChanged: {
            if (uiVisible && Window.window) Window.window.requestActivate();
            if (blockUI) fadeoutTimer.running = false;
            else if (uiVisible) fadeoutTimer.restart();
            authenticator.startAuthenticating();
            if (uiVisible) field.grab();
        }
        onBlockUIChanged: { if (blockUI) { fadeoutTimer.running = false; uiVisible = true; } else fadeoutTimer.restart(); }
        onExited: uiVisible = false
        Keys.onEscapePressed: {
            // Escape: kscreenlocker turns the screen off; discard the input
            if (uiVisible) { uiVisible = false; root.clearPassword(); }
        }
        Keys.onPressed: event => { uiVisible = true; event.accepted = false; }

        Timer {
            id: fadeoutTimer
            interval: 10000
            onTriggered: if (!screen.blockUI) screen.uiVisible = false
        }
        Timer { id: notificationRemoveTimer; interval: 3000; onTriggered: root.notification = "" }
        Timer {
            id: graceLockTimer
            interval: 3000
            onTriggered: { root.clearPassword(); authenticator.startAuthenticating(); }
        }

        // idle: clock panel in the front panel color
        Bevel {
            id: idlePlate
            visible: !screen.uiVisible
            anchors.centerIn: parent
            base: pal.panel
            width: idleCol.implicitWidth + 2 * pal.u
            height: idleCol.implicitHeight + 2 * pal.u
            ColumnLayout {
                id: idleCol
                anchors.centerIn: parent
                spacing: Math.round(pal.u / 2)
                SevenSeg {
                    pal: pal
                    base: pal.panel
                    now: ui.now
                    Layout.preferredHeight: 4 * pal.u
                    Layout.preferredWidth: 12 * pal.u
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    renderType: pal.renderType
                    Layout.alignment: Qt.AlignHCenter
                    text: ui.now.toLocaleDateString(Qt.locale(), "dddd, d. MMMM yyyy")
                    font: pal.font
                    color: pal.panelText
                }
                Text {
                    renderType: pal.renderType
                    Layout.alignment: Qt.AlignHCenter
                    text: T.t("%1 – gesperrt", "%1 – locked").arg(kuser.host)
                    font.family: pal.font.family
                    font.bold: true
                    font.pixelSize: Math.round(pal.u * 1.1)
                    color: pal.panelText
                }
            }
        }

        Panel {
            id: dialog
            pal: pal
            visible: screen.uiVisible
            anchors.centerIn: parent
            transform: Translate { id: shakeX }

            ColumnLayout {
                width: Math.max(implicitWidth, 30 * pal.u)
                spacing: pal.u

                Header {
                    pal: pal
                    greeting: T.t("Gesperrt seit %1", "Locked since %1").arg(ui.lockedAt.toLocaleTimeString(Qt.locale(), "HH:mm"))
                    host: kuser.host
                    subtitle: ui.fullName !== "" ? ui.fullName + " (" + ui.userName + ")" : ui.userName
                    now: ui.now
                    Layout.fillWidth: true
                }
                Etch { base: pal.bg; Layout.fillWidth: true }

                Text {
                    renderType: pal.renderType
                    Layout.alignment: Qt.AlignHCenter
                    font: pal.font
                    color: pal.fg
                    text: ui.noPassword ? T.t("Kein Passwort nötig.", "No password required.")
                                        : T.t("Passwort eingeben, um zu entsperren:", "Enter password to unlock:")
                }
                MField {
                    id: field
                    pal: pal
                    password: true
                    visible: !ui.noPassword
                    enabled: !authenticator.graceLocked && !graceLockTimer.running
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 20 * pal.u
                    text: PasswordSync.password
                    onAccepted: ui.unlock()
                    KeyNavigation.tab: okButton
                }
                Binding { target: PasswordSync; property: "password"; value: field.text }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: pal.u
                    spacing: Math.round(pal.u / 2)
                    Lamp { pal: pal; busy: graceLockTimer.running; visible: busy }
                    Text {
                        renderType: pal.renderType
                        font: pal.font
                        color: root.notification !== "" ? pal.alert : pal.fg
                        horizontalAlignment: Text.AlignHCenter
                        text: {
                            const parts = [];
                            if (capsLockState.locked) parts.push(T.t("Feststelltaste ist aktiv", "Caps Lock is on"));
                            if (root.notification) parts.push(root.notification);
                            return parts.join("  ·  ");
                        }
                    }
                }
                Loader {
                    id: media
                    Layout.fillWidth: true
                    visible: item !== null && item.visible
                    Layout.preferredHeight: visible ? item.implicitHeight : 0
                    active: config.showMediaControls
                    source: "MediaControls.qml"
                }
                Etch { base: pal.bg; Layout.fillWidth: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: pal.u
                    MButton { id: okButton; pal: pal; text: T.t("&Entsperren", "&Unlock"); isDefault: true; onClicked: ui.unlock(); Layout.fillWidth: true }
                    MButton { id: sleepButton; pal: pal; text: T.t("&Bereitschaft", "Slee&p"); visible: sessionManagement.canSuspend; onClicked: sessionManagement.suspend(); Layout.fillWidth: true }
                    MButton { id: hibButton; pal: pal; text: T.t("&Ruhezustand", "&Hibernate"); visible: sessionManagement.canHibernate; onClicked: sessionManagement.hibernate(); Layout.fillWidth: true }
                    MButton { id: switchButton; pal: pal; text: T.t("Benutzer &wechseln", "S&witch User"); visible: sessionManagement.canSwitchUser; onClicked: sessionManagement.switchUser(); Layout.fillWidth: true }
                    MButton {
                        id: layoutButton
                        pal: pal
                        visible: layoutSwitcher.hasMultipleKeyboardLayouts
                        text: layoutSwitcher.layoutNames.shortName ? layoutSwitcher.layoutNames.shortName.toUpperCase() : "?"
                        onClicked: layoutSwitcher.keyboardLayout.switchToNextLayout()
                        PW.KeyboardLayoutSwitcher { id: layoutSwitcher; anchors.fill: parent; acceptedButtons: Qt.NoButton }
                    }
                }
            }
            SequentialAnimation {
                id: shake
                NumberAnimation { target: shakeX; property: "x"; to: -pal.u; duration: 50 }
                NumberAnimation { target: shakeX; property: "x"; to: pal.u; duration: 80 }
                NumberAnimation { target: shakeX; property: "x"; to: -pal.u / 2; duration: 70 }
                NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 50 }
            }
        }

        Loader {
            z: 2
            active: root.viewVisible
            source: "LockOsd.qml"
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: pal.u }
        }
    }

    // Alt+letter triggers the matching button
    Keys.onPressed: e => {
        if (!(e.modifiers & Qt.AltModifier) || !screen.uiVisible) return;
        const c = e.text.toLowerCase() || String.fromCharCode(e.key).toLowerCase();
        for (const b of [okButton, sleepButton, hibButton, switchButton]) {
            if (b.visible && b.mnemonic === c) { b.clicked(); e.accepted = true; return; }
        }
    }
}
