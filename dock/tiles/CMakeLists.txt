plasma_add_applet(org.kde.schiefer.tiles
    QML_SOURCES main.qml Bevel.qml FrameTint.qml PanelFit.qml MotifArrow.qml TrayItemIcon.qml config.qml ConfigGeneral.qml
    CPP_SOURCES schiefertray.cpp schieferscheme.cpp
    RESOURCES main.xml
    GENERATE_APPLET_CLASS
)
target_link_libraries(org.kde.schiefer.tiles PRIVATE Qt6::Quick KF6::KirigamiPlatform Plasma::Plasma Plasma::PlasmaQuick KF6::ConfigCore)
