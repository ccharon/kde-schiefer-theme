plasma_add_applet(org.kde.schiefer.drawer
    QML_SOURCES main.qml Bevel.qml FrameTint.qml MotifArrow.qml DrawerPopup.qml ClockFace.qml DateFace.qml SystemFace.qml TrayItemIcon.qml config.qml ConfigGeneral.qml
    CPP_SOURCES schieferhelper.cpp schieferscheme.cpp schiefertray.cpp schieferfolder.cpp
    RESOURCES main.xml
    GENERATE_APPLET_CLASS
)
target_link_libraries(org.kde.schiefer.drawer PRIVATE Qt6::Quick KF6::KirigamiPlatform Qt6::DBus KF6::KIOWidgets KF6::KIOFileWidgets KF6::KIOGui KF6::Service KF6::ConfigCore KF6::Notifications Plasma::Plasma Plasma::PlasmaQuick)
# C++ strings (i18n) in the same translation domain as the applet's QML strings
target_link_libraries(org.kde.schiefer.drawer PRIVATE KF6::I18n)
target_compile_definitions(org.kde.schiefer.drawer PRIVATE TRANSLATION_DOMAIN="plasma_applet_org.kde.schiefer.drawer")
