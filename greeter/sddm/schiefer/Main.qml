/*
 * Schiefer login (SDDM) in the style of classic Unix workstations:
 * pattern backdrop, dialog panel with the host name, the user as an option menu (list from SDDM
 * or "Other User..." to type a name), the password below. The last logged-in user is
 * preselected (SDDM remembers it, RememberLastUser), or the only user if there is one;
 * "Start Over" asks for the name.
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
        if (userModel.lastUser && userModel.lastUser !== "") {
            userName = userModel.lastUser;
            stage = "pass";
        }
        Qt.callLater(() => {
            if (stage === "user" && users.length === 1) chooseUser(users[0]);
            else focusField();
        });
    }

    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    // collect real names and session names
    property var realNames: ({})
    property var users: []
    Instantiator {
        model: userModel
        delegate: QtObject {
            required property int index
            required property string name
            required property string realName
            Component.onCompleted: {
                const m = root.realNames; m[name] = realName; root.realNames = m;
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

    function displayName(n) { const r = realNames[n]; return r && r !== "" && r !== n ? r + " (" + n + ")" : n; }

    function focusField() { if (stage === "user") nameField.grab(); else field.grab(); }
    function chooseUser(n) {
        userName = n;
        message = "";
        stage = "pass";
        field.clear();
        field.grab();
    }
    function proceed() {
        if (stage === "user") {
            const n = nameField.text.trim();
            if (n === "") return;
            chooseUser(n);
        } else if (stage === "pass") {
            stage = "busy";
            message = "";
            sddm.login(userName, field.text, sessionIndex);
        }
    }
    function startOver() {
        stage = "user";
        userName = "";
        message = "";
        field.clear();
        nameField.clear();
        nameField.grab();
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.stage = "pass";
            root.message = T.t("Anmeldung fehlgeschlagen. Bitte erneut versuchen.", "Login incorrect. Please try again.");
            field.clear();
            field.grab();
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
        padding: pal.u

        ColumnLayout {
            id: body
            width: Math.max(implicitWidth, 30 * pal.u)
            spacing: pal.u

            Header {
                pal: pal
                greeting: T.t("Willkommen auf", "Welcome to")
                host: root.host
                subtitle: config.subtitle || root.osName
                showClock: String(config.showClock) !== "false"
                now: root.now
                Layout.fillWidth: true
            }
            Etch { base: pal.bg; Layout.fillWidth: true }

            // user and password as a labeled grid (like dtlogin, but with a choice)
            GridLayout {
                Layout.alignment: Qt.AlignHCenter
                columns: 2
                columnSpacing: Math.round(pal.u * 0.6)
                rowSpacing: Math.round(pal.u * 0.5)
                Text {
                    renderType: pal.renderType
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    font: pal.font
                    color: pal.fg
                    textFormat: Text.StyledText
                    text: T.t("<u>B</u>enutzer:", "<u>U</u>ser:")
                }
                Item {
                    Layout.preferredWidth: 20 * pal.u
                    Layout.preferredHeight: Math.max(nameField.implicitHeight, userOption.implicitHeight)
                    MField {
                        id: nameField
                        pal: pal
                        anchors.fill: parent
                        visible: root.stage === "user"
                        onAccepted: root.proceed()
                        input.Keys.onDownPressed: root.openUsers()
                        KeyNavigation.tab: okButton
                    }
                    MOption {
                        id: userOption
                        pal: pal
                        anchors.fill: parent
                        visible: root.stage !== "user"
                        enabled: root.stage !== "busy"
                        text: root.displayName(root.userName)
                        onActivated: root.openUsers()
                        KeyNavigation.tab: field.input
                    }
                }
                Text {
                    renderType: pal.renderType
                    visible: root.stage !== "user"
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    font: pal.font
                    color: pal.fg
                    text: T.t("Passwort:", "Password:")
                }
                MField {
                    id: field
                    pal: pal
                    visible: root.stage !== "user"
                    password: true
                    enabled: root.stage !== "busy"
                    Layout.preferredWidth: 20 * pal.u
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
            Etch { base: pal.bg; Layout.fillWidth: true }

            RowLayout {
                id: buttons
                Layout.fillWidth: true
                spacing: pal.u
                MButton { id: okButton; pal: pal; text: T.t("&OK", "&OK"); isDefault: true; enabled: root.stage !== "busy"; onClicked: root.proceed(); Layout.fillWidth: true; KeyNavigation.tab: againButton }
                MButton { id: againButton; pal: pal; text: T.t("&Neu beginnen", "&Start Over"); enabled: root.stage !== "busy"; onClicked: root.startOver(); Layout.fillWidth: true; KeyNavigation.tab: optButton }
                MButton { id: optButton; pal: pal; text: T.t("O&ptionen …", "O&ptions …"); onClicked: root.openOptions(); Layout.fillWidth: true; KeyNavigation.tab: root.stage === "user" ? nameField.input : userOption }
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

    function openUsers() {
        if (stage === "busy") return;
        const e = [];
        for (const n of users) e.push({ type: "radio", text: displayName(n), checked: stage !== "user" && n === userName, action: () => root.chooseUser(n) });
        if (e.length > 0) e.push({ type: "sep" });
        e.push({ type: "item", text: T.t("Anderer Benutzer …", "Other User …"), action: () => root.startOver() });
        menu.entries = e;
        menu.open(stage === "user" ? nameField : userOption, true);
    }

    MMenu {
        id: menu
        pal: pal
        anchors.fill: parent
        onClosed: root.focusField()
    }

    // Alt+letter triggers the button with this mnemonic (Motif always shows them)
    Keys.onPressed: e => {
        if (!(e.modifiers & Qt.AltModifier) || menu.visible) return;
        const c = e.text.toLowerCase() || String.fromCharCode(e.key).toLowerCase();
        if (c === T.t("b", "u")) { root.openUsers(); e.accepted = true; return; }
        for (const b of [okButton, againButton, optButton]) {
            if (b.enabled && b.mnemonic === c) { b.clicked(); e.accepted = true; return; }
        }
    }
}
