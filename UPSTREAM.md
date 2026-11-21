# Updating to a new Breeze version

The Qt style in `kstyle/` is a fork of `kde-plasma/breeze` (subdirectory `kstyle/`). It has three layers:

1. **Upstream, only renamed**: reproducible with `tools/import-upstream.sh` (namespace `Schiefer`, plugin key
   `Schiefer`, config file `schieferrc`). A copy of this state is in `kstyle/.upstream-base/`, its version in
   `kstyle/UPSTREAM_VERSION`.
2. **Own files**: `kstyle/CMakeLists.txt` (standalone build), `kstyle/test/` (gallery), `kstyle/render.sh`.
3. **Schiefer changes**: everything that differs between `.upstream-base/` and `kstyle/` (mainly
   `breezehelper.cpp`, `breezemetrics.h`, `breezestyle.cpp`). Changed spots are marked `// Schiefer:`.

The window decoration in `kdecoration/` is original code. It depends only on the KDecoration3 API and only needs
a rebuild on Plasma updates.

## Steps for a new Breeze version (for example 6.8.0)

```bash
NEW=/var/cache/distfiles/breeze-6.8.0.tar.xz

# 1. Save the Schiefer changes as a patch
diff -ruN -x build -x test -x render.sh -x CMakeLists.txt -x UPSTREAM_VERSION -x .upstream-base \
    kstyle/.upstream-base kstyle > schiefer.patch

# 2. Create the renamed upstream state
tools/import-upstream.sh "$NEW" kstyle-new

# 3. Apply the changes and resolve conflicts (*.rej) by hand
(cd kstyle-new && patch -p1 < ../schiefer.patch; find . -name '*.rej')

# 4. Copy the own files and store the new base (freshly imported, without the patch)
cp -r kstyle/CMakeLists.txt kstyle/test kstyle/render.sh kstyle-new/
tools/import-upstream.sh "$NEW" kstyle-new/.upstream-base

# 5. Compare SRCS in kstyle-new/CMakeLists.txt with the upstream kstyle/CMakeLists.txt

# 6. Build, compare the preview, replace the old directory
cmake -S kstyle-new -B kstyle-new/build -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DKDE_INSTALL_USE_QT_SYS_PATHS=ON
cmake --build kstyle-new/build
mkdir -p kstyle-new/build/plugins/styles && ln -sf ../../bin/schiefer6.so kstyle-new/build/plugins/styles/
kstyle-new/render.sh /tmp/preview.png
mv kstyle kstyle-old && mv kstyle-new kstyle
```

`KDE_COMPILERSETTINGS_LEVEL 5.82` in `kstyle/CMakeLists.txt` must stay as upstream has it; otherwise the build
fails at `QString(const char*)`.

## Plasma internals used by the dock

The system drawer (`org.kde.schiefer.drawer`, face "system") and the status tiles (`org.kde.schiefer.tiles`)
remote-control a hidden Plasma system tray (`dock/common/schiefertray.cpp`). There is no public API for this;
the bridge uses Qt meta objects to reach the following internals (paths relative to
`plasma-workspace/applets/systemtray/` and `libplasma/src/`). Check them after every Plasma update.

| Access in the bridge | Defined in | As of 6.7.6 |
|---|---|---|
| plugin ID `org.kde.plasma.systemtray` | `metadata.json` | |
| `property("systemTrayModel")` | `systemtray.h` | `Q_PROPERTY(QAbstractItemModel *systemTrayModel READ sortedSystemTrayModel CONSTANT)`; created on first read, needs `init()` |
| roles `itemType`, `itemId`, `effectiveStatus`, `status`, `displayText`, `decoration`, `applet`, `DataEngineSource`, `ToolTipTitle`, `ToolTipSubTitle`, `AttentionIcon(Name)` | `systemtraymodel.cpp` (`roleNames()`); `applet` returns `PlasmaQuick::AppletQuickItem*` | |
| `invokeMethod("activate", QString, QPoint, QQuickItem*)` | `systemtray.h` | `Q_INVOKABLE void activate(const QString &service, QPoint pos, QQuickItem *statusNotifierIcon)` |
| `invokeMethod("openContextMenu", QString, QPoint, QQuickItem*)` | `systemtray.h` | `Q_INVOKABLE void openContextMenu(const QString &service, QPoint pos, QQuickItem *statusNotifierIcon)` |
| `invokeMethod("scroll", QString, int, QString)` | `systemtray.h` | `Q_INVOKABLE void scroll(const QString &service, int delta, const QString &direction)` |
| popup with `objectName` `"popupWindow"` | `qml/main.qml` | `PlasmaCore.AppletPopup { id: dialog; objectName: "popupWindow"; visualParent: root }` |
| popup property `visualParent` | libplasma `plasmaquick/popupplasmawindow.h` | `Q_PROPERTY(QQuickItem *visualParent ...)`, a `QPointer` internally |
| `Q_EMIT applet->activated()` toggles the popup | `qml/main.qml` | `Connections { target: Plasmoid; function onActivated() { ... } }` |
| property `expanded` of `model.applet` | libplasma `plasmaquick/appletquickitem.h` | `Q_PROPERTY(bool expanded ...)` |
| `internalAction("configure")` | libplasma `plasma/private/applet_p.cpp` | standard action of every applet |
| the system tray sets `status` itself when expanding; the bridge resets it to `HiddenStatus` | `qml/SystemTrayState.qml` | |

If an access fails, the bridge reports it once per instance in the logging category `schiefer.dock`, for example
`schiefer.dock: system tray bridge: QMetaObject::invokeMethod("activate") on the system tray failed ...`.
`QT_LOGGING_RULES="schiefer.dock.debug=true"` also logs every popup reparenting.
