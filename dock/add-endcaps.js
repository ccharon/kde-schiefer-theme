// Schiefer-Dock: Abschlussstücke links und rechts in die vorhandene Leiste unten einfügen,
// ohne die Leiste neu aufzubauen (Einstellungen der Schubladen bleiben erhalten)
panels().forEach(function (p) {
    if (p.location !== "bottom" || p.widgets("org.kde.schiefer.endcap").length) return;
    if (!p.widgets("org.kde.schiefer.drawer").length) return;
    var r = p.addWidget("org.kde.schiefer.endcap");
    r.currentConfigGroup = ["General"];
    r.writeConfig("side", "right");
    var l = p.addWidget("org.kde.schiefer.endcap");
    l.currentConfigGroup = ["General"];
    l.writeConfig("side", "left");
    l.index = 0;
});
