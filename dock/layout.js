// Schiefer dock: create a sample front panel (Plasma script for evaluateScript)
// Removes existing panels at the bottom, left and right and rebuilds them:
// dock at the bottom, icon box on the left, status tiles at the top right.
function app(id) { return "applications:" + id + ".desktop"; }
function exists(id) { return applicationExists(id + ".desktop"); }
function pick() { for (var i = 0; i < arguments.length; ++i) if (exists(arguments[i])) return app(arguments[i]); return ""; }
function only() { var r = []; for (var i = 0; i < arguments.length; ++i) if (exists(arguments[i])) r.push(app(arguments[i])); return r; }

// Remember the settings of all widgets of the types in keepTypes so a rebuild keeps them:
// per type all instances in order (new widgets of the same type get them back in order).
// Drawers are matched by their title instead (by the "face" view for an empty title);
// without a matching old drawer this script's defaults apply.
var kept = {};
var keptDrawers = [];
var DRAWER = "org.kde.schiefer.drawer";
var keepTypes = ["org.kde.schiefer.tiles", "org.kde.plasma.systemtray", "org.kde.schiefer.iconbox", "org.kde.schiefer.console", DRAWER];
panels().forEach(function (p) {
    if (["bottom", "left", "right"].indexOf(p.location) < 0) return;
    p.widgets().forEach(function (w) {
        if (keepTypes.indexOf(w.type) < 0) return;
        w.currentConfigGroup = ["General"];
        var cfg = {};
        w.configKeys.forEach(function (k) { cfg[k] = w.readConfig(k); });
        if (w.type == DRAWER) {
            keptDrawers.push(cfg);
        } else {
            if (!kept[w.type]) kept[w.type] = [];
            kept[w.type].push(cfg);
        }
    });
});
function apply(w, cfg) {
    w.currentConfigGroup = ["General"];
    for (var k in cfg) w.writeConfig(k, cfg[k]);
}
function restore(w) {
    var q = kept[w.type];
    if (q && q.length) apply(w, q.shift());
    return w;
}
// find the old drawer for title/view and remove it from the list; null if none matches
function takeDrawer(face, title) {
    for (var i = 0; i < keptDrawers.length; ++i) {
        var c = keptDrawers[i];
        var t = c.title ? String(c.title) : "";
        var f = c.face ? String(c.face) : "launcher";
        if (title ? t == title : (t == "" && f == face)) return keptDrawers.splice(i, 1)[0];
    }
    return null;
}

panels().forEach(function (p) { if (["bottom", "left", "right"].indexOf(p.location) >= 0) p.remove(); });

var panel = new Panel;
panel.location = "bottom";
panel.height = Math.round(gridUnit * 4);
panel.floating = false;
panel.alignment = "center";
panel.lengthMode = "fit";
panel.hiding = "none";

// purely decorative end pieces on the left and right as on the CDE front panel
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
    var old = takeDrawer(face, title);
    if (old) apply(w, old);
    return w;
}

endcap("left");
drawer("clock", pick("org.kde.kclock"), only("org.kde.kclock"), "Uhr");
drawer("date", pick("org.kde.merkuro.calendar", "org.kde.korganizer"), only("org.kde.merkuro.calendar", "org.kde.korganizer", "org.kde.kcalc"), "Kalender");
drawer("launcher", pick("org.kde.dolphin"), only("org.kde.krusader", "org.kde.kfind", "org.kde.ark", "org.kde.filelight"), "Dateien");
// folder drawer: contents of the desktop folder
var desk = drawer("folder", "", [], "");
if (!desk.readConfig("folderUrl")) desk.writeConfig("folderUrl", "file://" + encodeURI(userDataPath("desktop")));
drawer("launcher", pick("org.kde.kate", "org.kde.kwrite"), only("org.kde.kwrite", "org.kde.okular", "org.kde.kcharselect", "org.kde.kdiff3"), "Texte");
drawer("launcher", pick("org.kde.konsole"), only("org.kde.spectacle", "org.kde.plasma-systemmonitor"), "Werkzeuge");

restore(panel.addWidget("org.kde.schiefer.console"));

drawer("launcher", pick("firefox", "firefox-esr", "org.mozilla.firefox", "chromium-browser-chromium"), only("thunderbird", "org.mozilla.Thunderbird", "org.kde.kget"), "Netz");
drawer("launcher", pick("systemsettings", "kdesystemsettings"), only("org.kde.kinfocenter", "org.kde.plasma-systemmonitor", "org.kde.discover", "org.kde.kmenuedit"), "Einstellungen");
drawer("launcher", "trash:/", [], "Papierkorb");
endcap("right");

// icon box on the left: all windows as Motif icons; dodges windows and slides out at the edge
var box = new Panel;
box.location = "left";
box.height = Math.round(gridUnit * 13);
box.floating = false;
box.alignment = "left";
// "custom" instead of "fit": with "fit" a panel never gets shorter than its thickness (panelview.cpp),
// but the icon box should shrink completely with few windows
box.lengthMode = "custom";
box.maximumLength = screenGeometry(box.screen).height;
box.minimumLength = Math.round(gridUnit * 3);
box.hiding = "dodgewindows";
restore(box.addWidget("org.kde.schiefer.iconbox"));

// status tiles at the top right (dockapps as in Window Maker); the Plasma system tray sits
// hidden in the same panel and hosts the entries
var tiles = new Panel;
tiles.location = "right";
tiles.height = Math.round(gridUnit * 3.4);   // 61 px at an 18 px grid unit
tiles.floating = false;
tiles.alignment = "left";
tiles.lengthMode = "fit";
tiles.hiding = "dodgewindows";
restore(tiles.addWidget("org.kde.plasma.systemtray"));
restore(tiles.addWidget("org.kde.schiefer.tiles"));
