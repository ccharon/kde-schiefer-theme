plasma_add_applet(org.kde.schiefer.tiles
    QML_SOURCES main.qml Bevel.qml MotifArrow.qml TrayItemIcon.qml config.qml ConfigGeneral.qml
    CPP_SOURCES schiefertray.cpp
    RESOURCES main.xml
    GENERATE_APPLET_CLASS
)
target_link_libraries(org.kde.schiefer.tiles PRIVATE Plasma::Plasma Plasma::PlasmaQuick)
