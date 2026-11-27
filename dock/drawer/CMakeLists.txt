plasma_add_applet(org.kde.schiefer.drawer
    QML_SOURCES main.qml ${DOCK_COMMON}/Bevel.qml ${DOCK_COMMON}/DockRow.qml ${DOCK_COMMON}/Ledge.qml ${DOCK_COMMON}/FrameTint.qml ${DOCK_COMMON}/MotifArrow.qml DrawerPopup.qml RunningMark.qml ClockFace.qml DateFace.qml SystemFace.qml ${DOCK_COMMON}/TrayItemIcon.qml config.qml ConfigGeneral.qml
    CPP_SOURCES ${DOCK_COMMON}/schieferhelper.cpp ${DOCK_COMMON}/schieferscheme.cpp ${DOCK_COMMON}/schiefertray.cpp schieferfolder.cpp
    RESOURCES main.xml
    GENERATE_APPLET_CLASS
)
target_link_libraries(org.kde.schiefer.drawer PRIVATE Qt6::Quick KF6::KirigamiPlatform Qt6::DBus KF6::KIOWidgets KF6::KIOFileWidgets KF6::KIOGui KF6::Service KF6::ConfigCore KF6::Notifications Plasma::Plasma Plasma::PlasmaQuick)
# C++ strings (i18n) in the same translation domain as the applet's QML strings
target_link_libraries(org.kde.schiefer.drawer PRIVATE KF6::I18n)
target_compile_definitions(org.kde.schiefer.drawer PRIVATE TRANSLATION_DOMAIN="plasma_applet_org.kde.schiefer.drawer")
