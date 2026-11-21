/*
 * Schiefer – Anmeldung (SDDM) im Stil klassischer Unix-Workstations:
 * Muster-Hintergrund, Dialogtafel mit Rechnername, ein Eingabefeld, das erst nach dem
 * Benutzernamen und dann nach dem Passwort fragt. Der zuletzt angemeldete Benutzer ist
 * vorbelegt, dann genügt das Passwort; „Neu beginnen“ fragt wieder nach dem Namen.
 * Optionen: Sitzung, Tastaturbelegung, Bereitschaft, Neu starten, Herunterfahren.
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
        fieldText: fg
        fontPoints: Number(config.fontSize) || 0
    }

    property string stage: "user"             // "user" | "pass" | "busy"
    property string userName: ""
    property string message: ""
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property date now: new Date()
    readonly property string host: (config.hostName && config.hostName !== "") ? config.hostName : (sddm.hostName || sysHost)
    property string sysHost: ""

    // Betriebssystem aus KCoreAddons, falls vorhanden (SDDM soll ohne KDE-Module nicht scheitern)
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
        Qt.callLater(() => field.grab());
    }

    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    // Echtnamen und Sitzungsnamen einsammeln
    property var realNames: ({})
    Instantiator {
        model: userModel
        delegate: QtObject {
            required property string name
            required property string realName
            Component.onCompleted: { const m = root.realNames; m[name] = realName; root.realNames = m; }
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

    function proceed() {
        if (stage === "user") {
            const n = field.text.trim();
            if (n === "") return;
            userName = n;
            message = "";
            stage = "pass";
            field.clear();
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
        field.grab();
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

    // Muster-Hintergrund wie die Arbeitsfläche (Köper), pixelgenau gekachelt
    Rectangle { anchors.fill: parent; color: config.backgroundColor || "#8fa3bf" }
    Image {
        anchors.fill: parent
        source: config.background ? Qt.resolvedUrl(config.background) : ""
        onStatusChanged: if (status === Image.Error) console.warn("Schiefer: Hintergrund fehlt:", source)
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

            Text {
                renderType: pal.renderType
                Layout.alignment: Qt.AlignHCenter
                font: pal.font
                color: pal.fg
                text: root.stage === "user" ? T.t("Bitte Benutzernamen eingeben:", "Please enter your user name:")
                    : T.t("Passwort für %1:", "Password for %1:").arg(root.displayName(root.userName))
            }
            MField {
                id: field
                pal: pal
                password: root.stage !== "user"
                enabled: root.stage !== "busy"
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 20 * pal.u
                onAccepted: root.proceed()
                input.Keys.onEscapePressed: root.startOver()
                KeyNavigation.tab: okButton
            }
            // Meldungszeile: Fehler, Feststelltaste, Anmeldung läuft
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
                MButton { id: optButton; pal: pal; text: T.t("O&ptionen …", "O&ptions …"); onClicked: root.openOptions(); Layout.fillWidth: true; KeyNavigation.tab: field.input }
            }
        }
    }

    // Unten: Sitzung und Tastaturbelegung als schlichte Statuszeile auf dem Muster
    Bevel {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: dialog.bottom
        anchors.topMargin: pal.u
        base: pal.bg
        width: statusLine.implicitWidth + 2 * pal.u
        height: statusLine.implicitHeight + Math.round(pal.u * 0.6)
        Text {
            renderType: pal.renderType
            id: statusLine
            anchors.centerIn: parent
            font: pal.font
            color: pal.fg
            text: {
                const parts = [T.t("Sitzung: ", "Session: ") + (root.sessions[root.sessionIndex] || "–")];
                if (keyboard.layouts.length > 1) parts.push(T.t("Tastatur: ", "Keyboard: ") + (keyboard.layouts[keyboard.currentLayout] ? keyboard.layouts[keyboard.currentLayout].longName : ""));
                return parts.join("    ");
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

    // Alt+Buchstabe löst den Knopf mit dieser Mnemonik aus (Motif zeigt sie immer)
    Keys.onPressed: e => {
        if (!(e.modifiers & Qt.AltModifier) || menu.visible) return;
        const c = e.text.toLowerCase() || String.fromCharCode(e.key).toLowerCase();
        for (const b of [okButton, againButton, optButton]) {
            if (b.enabled && b.mnemonic === c) { b.clicked(); e.accepted = true; return; }
        }
    }
}
