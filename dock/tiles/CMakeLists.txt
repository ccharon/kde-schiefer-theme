plasma_add_applet(org.kde.schiefer.tiles
    QML_SOURCES main.qml ${DOCK_COMMON}/Bevel.qml ${DOCK_COMMON}/FrameTint.qml ${DOCK_COMMON}/PanelFit.qml ${DOCK_COMMON}/MotifArrow.qml ${DOCK_COMMON}/TrayItemIcon.qml ${DOCK_COMMON}/Subpanel.qml ${DOCK_COMMON}/EntryFrame.qml ${DOCK_COMMON}/Lamp.qml config.qml ConfigGeneral.qml
    CPP_SOURCES ${DOCK_COMMON}/schiefertray.cpp ${DOCK_COMMON}/schieferscheme.cpp
    RESOURCES main.xml
    GENERATE_APPLET_CLASS
)
target_link_libraries(org.kde.schiefer.tiles PRIVATE Qt6::Quick KF6::KirigamiPlatform Plasma::Plasma Plasma::PlasmaQuick KF6::ConfigCore)
