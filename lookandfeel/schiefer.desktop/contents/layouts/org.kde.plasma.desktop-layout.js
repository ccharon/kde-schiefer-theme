// Desktop layout of the Schiefer global theme (applied with "Desktop and window layout").
// Same defaults as schiefer-config: front panel, pattern backdrop, desktop menu on the
// right button, window list on the middle button.

// The panels come from the layout template that schiefer-dock installs together with its
// widgets; without it the Plasma default panel.
if (!loadTemplate("org.kde.schiefer.dock"))
    loadTemplate("org.kde.plasma.desktop.defaultPanel");

// pattern backdrop (schiefer-backdrop), otherwise the image wallpaper from contents/defaults;
// knownWallpaperPlugins() is keyed by the translated plugin name, not by the id
var known = knownWallpaperPlugins();
var wallpaper = known.hasOwnProperty("Schiefer Patterns") || known.hasOwnProperty("Schiefer-Muster")
    ? "org.kde.schiefer.backdrop" : "org.kde.image";
var desktopsArray = desktopsForActivity(currentActivity());
for (var j = 0; j < desktopsArray.length; j++)
    desktopsArray[j].wallpaperPlugin = wallpaper;

var actions = ConfigFile(ConfigFile("plasma-org.kde.plasma.desktop-appletsrc", "ActionPlugins"), "0");
actions.writeEntry("RightButton;NoModifier", "org.kde.applauncher");
actions.writeEntry("MiddleButton;NoModifier", "switchwindow");
