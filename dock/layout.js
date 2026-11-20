// Schiefer-Dock: Beispiel-Frontpanel anlegen (Plasma-Skript für evaluateScript)
// Entfernt vorhandene Leisten unten, links und rechts und baut dort neu auf:
// Dock unten, Icon Box links, Statuskacheln rechts oben.
function app(id) { return "applications:" + id + ".desktop"; }
function exists(id) { return applicationExists(id + ".desktop"); }
function pick() { for (var i = 0; i < arguments.length; ++i) if (exists(arguments[i])) return app(arguments[i]); return ""; }
function only() { var r = []; for (var i = 0; i < arguments.length; ++i) if (exists(arguments[i])) r.push(app(arguments[i])); return r; }

// Einstellungen der Einzel-Widgets merken, damit ein erneuter Aufbau sie nicht verwirft
var kept = {};
var keepTypes = ["org.kde.schiefer.tiles", "org.kde.plasma.systemtray", "org.kde.schiefer.iconbox", "org.kde.schiefer.console"];
panels().forEach(function (p) {
    if (["bottom", "left", "right"].indexOf(p.location) < 0) return;
    p.widgets().forEach(function (w) {
        if (keepTypes.indexOf(w.type) < 0 || kept[w.type]) return;
        w.currentConfigGroup = ["General"];
        var cfg = {};
        w.configKeys.forEach(function (k) { cfg[k] = w.readConfig(k); });
        kept[w.type] = cfg;
    });
});
function restore(w) {
    var cfg = kept[w.type];
    if (!cfg) return w;
    w.currentConfigGroup = ["General"];
    for (var k in cfg) w.writeConfig(k, cfg[k]);
    return w;
}

panels().forEach(function (p) { if (["bottom", "left", "right"].indexOf(p.location) >= 0) p.remove(); });

var panel = new Panel;
panel.location = "bottom";
panel.height = Math.round(gridUnit * 4);
panel.floating = false;
panel.alignment = "center";
panel.lengthMode = "fit";
panel.hiding = "none";

// rein dekorative Abschlussstücke links und rechts wie beim CDE-Frontpanel
function endcap(side) {
    var w = panel.addWidget("org.kde.schiefer.endcap");
    w.currentConfigGroup = ["General"];
    w.writeConfig("side", side);
}

function drawer(face, main, list, title) {
    var w = panel.addWidget("org.kde.schiefer.drawer");
    w.currentConfigGroup = ["General"];
    w.writeConfig("face", face);
    if (main) w.writeConfig("mainUrl", main);
    if (list.length) w.writeConfig("drawerUrls", list);
    if (title) w.writeConfig("title", title);
    return w;
}

endcap("left");
drawer("clock", pick("org.kde.kclock"), only("org.kde.kclock"), "Uhr");
drawer("date", pick("org.kde.merkuro.calendar", "org.kde.korganizer"), only("org.kde.merkuro.calendar", "org.kde.korganizer", "org.kde.kcalc"), "Kalender");
drawer("launcher", pick("org.kde.dolphin"), only("org.kde.krusader", "org.kde.kfind", "org.kde.ark", "org.kde.filelight"), "Dateien");
// Ordner-Schublade: Inhalt des Schreibtischs
var desk = drawer("folder", "", [], "");
desk.writeConfig("folderUrl", "file://" + userDataPath("desktop"));
drawer("launcher", pick("org.kde.kate", "org.kde.kwrite"), only("org.kde.kwrite", "org.kde.okular", "org.kde.kcharselect", "org.kde.kdiff3"), "Texte");
drawer("launcher", pick("org.kde.konsole"), only("org.kde.spectacle", "org.kde.plasma-systemmonitor"), "Werkzeuge");

restore(panel.addWidget("org.kde.schiefer.console"));

drawer("launcher", pick("firefox", "firefox-esr", "org.mozilla.firefox", "chromium-browser-chromium"), only("thunderbird", "org.mozilla.Thunderbird", "org.kde.kget"), "Netz");
drawer("launcher", pick("systemsettings", "kdesystemsettings"), only("org.kde.kinfocenter", "org.kde.plasma-systemmonitor", "org.kde.discover", "org.kde.kmenuedit"), "Einstellungen");
drawer("launcher", "trash:/", [], "Papierkorb");
endcap("right");

// Icon Box links: alle Fenster als Motif-Symbole; weicht Fenstern aus und fährt am Rand heraus
var box = new Panel;
box.location = "left";
box.height = Math.round(gridUnit * 13);
box.floating = false;
box.alignment = "left";
// „custom“ statt „fit“: Bei „fit“ wird eine Leiste nie kürzer als ihre Dicke (panelview.cpp),
// die Icon Box soll aber bei wenigen Fenstern ganz zusammenschrumpfen
box.lengthMode = "custom";
box.maximumLength = screenGeometry(box.screen).height;
box.minimumLength = Math.round(gridUnit * 3);
box.hiding = "dodgewindows";
restore(box.addWidget("org.kde.schiefer.iconbox"));

// Statuskacheln rechts oben (Dockapps wie bei Window Maker); der Plasma-Systray steckt
// ausgeblendet in derselben Leiste und beherbergt die Einträge
var tiles = new Panel;
tiles.location = "right";
tiles.height = Math.round(gridUnit * 3.4);   // 61 px bei 18 px Rastereinheit
tiles.floating = false;
tiles.alignment = "left";
tiles.lengthMode = "fit";
tiles.hiding = "dodgewindows";
restore(tiles.addWidget("org.kde.plasma.systemtray"));
restore(tiles.addWidget("org.kde.schiefer.tiles"));
