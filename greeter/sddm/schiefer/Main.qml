/*
 * Schiefer login (SDDM) after the CDE login (dtlogin): pattern backdrop, dialog with the
 * greeting, one field that first asks for the user name and then for the password, a picture
 * panel with the clock on the right. The name field starts with the last logged-in user
 * (SDDM RememberLastUser) or the only user; "Start Over" empties it.
 * Options: session, keyboard layout, sleep, restart, shut down.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import "kit"
import "kit/T.js" as T

Item {
    id: root
    width: 1600
    height: 900

    Pal {
        id: pal
        bg: config.dialogColor || "#bec2d3"
        field: config.fieldColor || "#e2e5ed"
        active: config.activeColor || "#60729e"
        activeText: config.activeTextColor || "#ffffff"
        fg: config.textColor || "#000000"
        fieldText: config.fieldTextColor || fg
        alert: config.alertColor || "#a02828"
        fontPoints: Number(config.fontSize) || 0
    }

    property string stage: "user"             // "user" | "pass" | "busy"
    property string userName: ""
    property string message: ""
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property date now: new Date()
    readonly property string host: (config.hostName && config.hostName !== "") ? config.hostName : (sddm.hostName || sysHost)
    property string sysHost: ""

    // operating system from KCoreAddons if present (SDDM must not fail without KDE modules)
    property string osName: ""
    Component.onCompleted: {
        try {
            const u = Qt.createQmlObject('import org.kde.coreaddons as K; K.KUser {}', root);
            osName = u.os || "";
            sysHost = u.host || "";
        } catch (e) { osName = ""; }
        Qt.callLater(() => askName(userModel.lastUser || (users.length === 1 ? users[0] : "")));
    }

    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    // collect user and session names
    property var users: []
    Instantiator {
        model: userModel
        delegate: QtObject {
            required property int index
            required property string name
            Component.onCompleted: {
                const u = root.users.slice(); u[index] = name; root.users = u.filter(x => x !== undefined);
            }
        }
    }
    property var sessions: []
    Instantiator {
        model: sessionModel
        delegate: QtObject {
            required property int index
            required property string name
            Component.onCompleted: { const s = root.sessions.slice(); s[index] = name; root.sessions = s; }
        }
    }

    // stage "user": the field asks for the name, prefilled and selected so that typing replaces it
    function askName(n) {
        stage = "user";
        userName = "";
        field.text = n;
        field.input.selectAll();
        field.grab();
    }
    function proceed() {
        if (stage === "user") {
            const n = field.text.trim();
            if (n === "") return;
            userName = n;
            message = "";
            stage = "pass";
            field.clear();
            field.grab();
        } else if (stage === "pass") {
            stage = "busy";
            message = "";
            sddm.login(userName, field.text, sessionIndex);
        }
    }
    function startOver() {
        message = "";
        askName("");
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.message = T.t("Anmeldung fehlgeschlagen. Bitte erneut versuchen.", "Login incorrect. Please try again.");
            root.askName(root.userName);
        }
        function onLoginSucceeded() { root.message = ""; }
    }

    // pattern backdrop like the desktop (twill), tiled pixel-exact
    Rectangle { anchors.fill: parent; color: config.backgroundColor || "#8fa3bf" }
    Image {
        anchors.fill: parent
        source: config.background ? Qt.resolvedUrl(config.background) : ""
        onStatusChanged: if (status === Image.Error) console.warn("Schiefer: backdrop missing:", source)
        fillMode: Image.Tile
        smooth: false
        visible: status === Image.Ready
    }

    Panel {
        id: dialog
        pal: pal
        anchors.centerIn: parent
        padding: Math.round(pal.u * 0.5)

        RowLayout {
            spacing: Math.round(pal.u * 0.5)

            ColumnLayout {
                id: body
                spacing: Math.round(pal.u * 0.5)
                Layout.preferredWidth: 28 * pal.u
                Layout.fillHeight: true
                Layout.margins: Math.round(pal.u * 0.5)

                Text {
                    renderType: pal.renderType
                    Layout.fillWidth: true
                    Layout.topMargin: Math.round(pal.u * 0.5)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: T.t("Willkommen auf ", "Welcome to ") + root.host
                    color: pal.fg
                    font.family: pal.font.family
                    font.pixelSize: Math.round(pal.u * 1.3)
                }
                Text {
                    renderType: pal.renderType
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    visible: text !== ""
                    text: config.subtitle || root.osName
                    font: pal.font
                    color: pal.fg
                    opacity: 0.8
                }
                Item { Layout.fillHeight: true; Layout.minimumHeight: Math.round(pal.u * 0.5) }

                // prompt and field, as in dtlogin one after the other
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Math.round(pal.u * 0.25)
                    Text {
                        renderType: pal.renderType
                        font: pal.font
                        color: pal.fg
                        text: root.stage === "user" ? T.t("Bitte Benutzernamen eingeben", "Please enter your user name")
                                                    : T.t("Bitte Passwort eingeben", "Please enter your password")
                    }
                    MField {
                        id: field
                        pal: pal
                        password: root.stage !== "user"
                        enabled: root.stage !== "busy"
                        Layout.preferredWidth: 18 * pal.u
                        onAccepted: root.proceed()
                        input.Keys.onEscapePressed: root.startOver()
                        KeyNavigation.tab: okButton
                    }
                }
                // message line: errors, Caps Lock, login in progress
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: pal.u
                    spacing: Math.round(pal.u / 2)
                    Lamp { pal: pal; busy: root.stage === "busy"; visible: busy; Layout.alignment: Qt.AlignVCenter }
                    Text {
                        renderType: pal.renderType
                        font: pal.font
                        color: root.message !== "" ? pal.alert : pal.fg
                        text: {
                            const parts = [];
                            if (root.stage === "busy") parts.push(T.t("Anmeldung läuft …", "Logging in …"));
                            if (root.message !== "") parts.push(root.message);
                            if (keyboard.capsLock) parts.push(T.t("Feststelltaste ist aktiv", "Caps Lock is on"));
                            return parts.join("  ·  ");
                        }
                    }
                }

                // buttons spread over the width like in dtlogin
                RowLayout {
                    id: buttons
                    Layout.fillWidth: true
                    spacing: 0
                    Item { Layout.fillWidth: true }
                    MButton { id: okButton; pal: pal; text: T.t("&OK", "&OK"); isDefault: true; enabled: root.stage !== "busy"; onClicked: root.proceed(); Layout.preferredWidth: 7 * pal.u; KeyNavigation.tab: againButton }
                    Item { Layout.fillWidth: true }
                    MButton { id: againButton; pal: pal; text: T.t("&Neu beginnen", "&Start Over"); enabled: root.stage !== "busy"; onClicked: root.startOver(); Layout.preferredWidth: 7 * pal.u; KeyNavigation.tab: optButton }
                    Item { Layout.fillWidth: true }
                    MButton { id: optButton; pal: pal; text: T.t("O&ptionen …", "O&ptions …"); onClicked: root.openOptions(); Layout.preferredWidth: 7 * pal.u; KeyNavigation.tab: field.input }
                    Item { Layout.fillWidth: true }
                }
            }

            Logo {
                pal: pal
                image: config.logo || ""
                showClock: String(config.showClock) !== "false"
                now: root.now
                Layout.fillHeight: true
                Layout.preferredWidth: 14 * pal.u
            }
        }
    }

    function openOptions() {
        const e = [{ type: "title", text: T.t("Sitzung", "Session") }];
        for (let i = 0; i < sessions.length; ++i) {
            const idx = i;
            e.push({ type: "radio", text: sessions[i], checked: i === sessionIndex, action: () => { root.sessionIndex = idx; } });
        }
        if (keyboard.layouts.length > 1) {
            e.push({ type: "sep" }, { type: "title", text: T.t("Tastatur", "Keyboard") });
            for (let i = 0; i < keyboard.layouts.length; ++i) {
                const idx = i;
                e.push({ type: "radio", text: keyboard.layouts[i].longName, checked: i === keyboard.currentLayout, action: () => { keyboard.currentLayout = idx; } });
            }
        }
        e.push({ type: "sep" });
        if (sddm.canSuspend) e.push({ type: "item", text: T.t("Bereitschaft", "Suspend"), action: () => sddm.suspend() });
        if (sddm.canHibernate) e.push({ type: "item", text: T.t("Ruhezustand", "Hibernate"), action: () => sddm.hibernate() });
        e.push({ type: "item", text: T.t("Neu starten", "Restart"), enabled: sddm.canReboot, action: () => sddm.reboot() });
        e.push({ type: "item", text: T.t("Herunterfahren", "Shut Down"), enabled: sddm.canPowerOff, action: () => sddm.powerOff() });
        menu.entries = e;
        menu.open(optButton);
    }

    MMenu {
        id: menu
        pal: pal
        anchors.fill: parent
        onClosed: field.grab()
    }

    // Alt+letter triggers the button with this mnemonic (Motif always shows them)
    Keys.onPressed: e => {
        if (!(e.modifiers & Qt.AltModifier) || menu.visible) return;
        const c = e.text.toLowerCase() || String.fromCharCode(e.key).toLowerCase();
        for (const b of [okButton, againButton, optButton]) {
            if (b.enabled && b.mnemonic === c) { b.clicked(); e.accepted = true; return; }
        }
    }
}
