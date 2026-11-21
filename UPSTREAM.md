# Schiefer – Aktualisieren auf eine neue Breeze-Version

Der Qt-Stil in `kstyle/` ist ein Fork von `kde-plasma/breeze` (Unterordner `kstyle/`).
Er besteht aus drei Schichten:

1. **Upstream, nur umbenannt** – reproduzierbar mit `tools/import-upstream.sh`
   (Namespace `Schiefer`, Plugin-Schlüssel `Schiefer`, Konfigdatei `schieferrc`).
   Eine Kopie dieses Stands liegt in `kstyle/.upstream-base/`, die Version in `kstyle/UPSTREAM_VERSION`.
2. **Eigene Dateien** – `kstyle/CMakeLists.txt` (eigenständiger Build), `kstyle/test/` (Galerie),
   `kstyle/render.sh` (Offscreen-Vorschau).
3. **Retro-Änderungen** – alles, was sich zwischen `.upstream-base/` und `kstyle/` unterscheidet
   (vor allem `breezehelper.cpp`, `breezemetrics.h`, `breezestyle.cpp`).

Die Fensterdekoration in `kdecoration/` ist **kein** Fork, sondern eigener Code. Sie hängt nur an der
KDecoration3-API und muss bei Plasma-Updates lediglich neu kompiliert werden.

## Vorgehen bei einer neuen Breeze-Version (z. B. 6.8.0)

```bash
cd ~/claude/schiefer
NEU=/var/cache/distfiles/breeze-6.8.0.tar.xz

# 1. Eigene Änderungen als Patch sichern (ohne Build/Test/eigene Dateien)
diff -ruN -x build -x test -x render.sh -x CMakeLists.txt -x UPSTREAM_VERSION -x .upstream-base \
    kstyle/.upstream-base kstyle > retro.patch

# 2. Neuen Upstream-Stand umbenannt erzeugen
tools/import-upstream.sh "$NEU" kstyle-neu

# 3. Retro-Änderungen einspielen und Konflikte (*.rej) von Hand lösen
cd kstyle-neu && patch -p1 < ../retro.patch ; find . -name '*.rej'

# 4. Eigene Dateien übernehmen und neue Basis ablegen
cp -r ../kstyle/CMakeLists.txt ../kstyle/test ../kstyle/render.sh .
cd ..
#    Neue Basis = frisch importierter Stand (ohne Patch!):
tools/import-upstream.sh "$NEU" kstyle-neu/.upstream-base

# 5. CMakeLists.txt prüfen: hat Upstream Quelldateien hinzugefügt/entfernt?
#    -> Liste SRCS mit src/.../kstyle/CMakeLists.txt der neuen Version abgleichen.

# 6. Bauen, Vorschau prüfen, dann alten Ordner ersetzen
cmake -S kstyle-neu -B kstyle-neu/build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DCMAKE_INSTALL_PREFIX=/usr -DKDE_INSTALL_USE_QT_SYS_PATHS=ON
cmake --build kstyle-neu/build
mkdir -p kstyle-neu/build/plugins/styles && ln -sf ../../bin/schiefer6.so kstyle-neu/build/plugins/styles/
kstyle-neu/render.sh /tmp/vorschau.png        # mit der alten Vorschau vergleichen
mv kstyle kstyle-alt && mv kstyle-neu kstyle
```

Danach installieren (`sudo cmake --install kstyle/build`) und Programme neu starten.
Für die Dekoration: `cmake --build kdecoration/build && sudo cmake --install kdecoration/build`,
danach `kwin_wayland --replace`.

## Hinweise
- `KDE_COMPILERSETTINGS_LEVEL 5.82` in `kstyle/CMakeLists.txt` muss bleiben (wie Upstream),
  sonst schlägt der Build an `QString(const char*)` fehl.
- Die Breeze-Quellen liegen im Gentoo-Distfiles-Cache: `/var/cache/distfiles/breeze-<version>.tar.xz`.
- Langfristig sauberer: ein Ebuild im lokalen Overlay, das bei Plasma-Updates automatisch neu baut.

## Pakete (Gentoo, lokales Overlay)

Vier Pakete in `x11-themes`, Vorlagen in `packaging/x11-themes/*/<paket>.ebuild`:

| Paket | Inhalt | Neubau nötig bei |
|---|---|---|
| `schiefer-kde` | Fensterdekoration + Qt-Stil (C++) | Qt-Update (`qtbase:6=`), ABI-Bruch von kdecoration (`kdecoration:6=`) – automatisch |
| `schiefer-icons` | Icons, beim Bauen aus breeze-icons erzeugt | neue breeze-icons (von Hand: `emerge -1 schiefer-icons`) |
| `schiefer-themes` | Farbschema, Plasma-Stil, GTK-Theme, Hintergrund, `schiefer-wallpaper` | nur bei eigenen Änderungen |
| `schiefer` | globales Design + Metapaket | nur bei eigenen Änderungen |

Neue Version veröffentlichen:
```bash
echo 0.2 > VERSION                 # Version erhöhen
tools/install-overlay.sh           # packt dist/, kopiert als root ins Overlay, digest, root:root, 644/755
emerge -av x11-themes/schiefer
```
Anderer Rechner (z. B. MacBook mit Gentoo Asahi, arm64): `tools/make-dist.sh`, dann `dist/` hinüberkopieren
und dort `dist/install-overlay.sh` aufrufen.

## Plasma-Interna des Docks – nach jedem Plasma-Update prüfen

Die System-Schublade (`org.kde.schiefer.drawer`, Ansicht „system“) und die Statuskacheln
(`org.kde.schiefer.tiles`) steuern einen ausgeblendeten Plasma-Systray fern
(`dock/common/schiefertray.cpp`). Dafür gibt es keine öffentliche API; die Brücke greift über
Qt-Metaobjekte auf folgende Interna zu (Pfade relativ zu `src/plasma-workspace-6.7.6/applets/systemtray/`
bzw. `src/libplasma-6.7.6/src/`):

| Zugriff in der Brücke | Definiert in | Stand 6.7.6 |
|---|---|---|
| Plugin-ID `org.kde.plasma.systemtray` | `metadata.json` | – |
| `property("systemTrayModel")` | `systemtray.h` | `Q_PROPERTY(QAbstractItemModel *systemTrayModel READ sortedSystemTrayModel CONSTANT)`; das Modell entsteht beim ersten Lesen (`systemtray.cpp`, `systemTrayModel()`), braucht aber `init()` |
| Rollen `itemType`, `itemId`, `effectiveStatus`, `status`, `displayText`, `decoration`, `applet`, `DataEngineSource`, `ToolTipTitle`, `ToolTipSubTitle`, `AttentionIcon(Name)` (QML) | `systemtraymodel.cpp` (`roleNames()`); `applet` liefert `PlasmaQuick::AppletQuickItem*` | – |
| `invokeMethod("activate", QString, QPoint, QQuickItem*)` | `systemtray.h` | `Q_INVOKABLE void activate(const QString &service, QPoint pos, QQuickItem *statusNotifierIcon)` |
| `invokeMethod("openContextMenu", QString, QPoint, QQuickItem*)` | `systemtray.h` | `Q_INVOKABLE void openContextMenu(const QString &service, QPoint pos, QQuickItem *statusNotifierIcon)` |
| `invokeMethod("scroll", QString, int, QString)` | `systemtray.h` | `Q_INVOKABLE void scroll(const QString &service, int delta, const QString &direction)` („Horizontal“/„Vertical“) |
| Popup mit `objectName` `"popupWindow"` | `qml/main.qml` | `PlasmaCore.AppletPopup { id: dialog; objectName: "popupWindow"; visualParent: root }` |
| Property `visualParent` des Popups | libplasma `plasmaquick/popupplasmawindow.h` | `Q_PROPERTY(QQuickItem *visualParent …)`, intern `QPointer` |
| `Q_EMIT applet->activated()` schaltet das Popup um | `qml/main.qml` | `Connections { target: Plasmoid; function onActivated() { systemTrayState.expanded = !… } }` |
| Property `expanded` von `model.applet` | libplasma `plasmaquick/appletquickitem.h` | `Q_PROPERTY(bool expanded …)` |
| `internalAction("configure")` | libplasma `plasma/private/applet_p.cpp` | Standardaktion jedes Applets |
| Systray setzt beim Auf-/Zuklappen selbst `status` (die Brücke setzt es zurück auf `HiddenStatus`) | `qml/SystemTrayState.qml` (`onExpandedChanged` → `Plasmoid.status`) | – |

Schlägt einer dieser Zugriffe fehl, meldet die Brücke das **einmal** pro Instanz in der
Logging-Kategorie `schiefer.dock`, z. B.
`schiefer.dock: Systray-Brücke: QMetaObject::invokeMethod("activate") am Systray ist fehlgeschlagen …`.
Prüfen nach einem Update: Signaturen oben mit der neuen Quelle vergleichen
(`grep -n "Q_INVOKABLE\|Q_PROPERTY" systemtray.h`, `grep -n popupWindow qml/main.qml`), dann im
isolierten Test (`README.md`, Dock-Beispiel mit `SCHIEFER_DOCK_OPEN=System` bzw.
`SCHIEFER_DOCK_TRAY=org.kde.plasma.volume` und `BR_LOG=…`) das Log auf `schiefer.dock` durchsuchen.
Mit `QT_LOGGING_RULES="schiefer.dock.debug=true"` zeigt die Brücke außerdem jedes Umhängen des Popups.
