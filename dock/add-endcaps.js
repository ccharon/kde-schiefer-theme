// Schiefer dock: add end pieces on the left and right of the existing bottom panel
// without rebuilding the panel (the drawer settings are kept)
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
