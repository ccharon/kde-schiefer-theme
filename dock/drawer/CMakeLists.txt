plasma_add_applet(org.kde.schiefer.drawer
    QML_SOURCES main.qml Bevel.qml MotifArrow.qml DrawerPopup.qml ClockFace.qml DateFace.qml SystemFace.qml TrayItemIcon.qml config.qml ConfigGeneral.qml
    CPP_SOURCES schieferhelper.cpp schiefertray.cpp schieferfolder.cpp
    RESOURCES main.xml
    GENERATE_APPLET_CLASS
)
target_link_libraries(org.kde.schiefer.drawer PRIVATE Qt6::DBus KF6::KIOWidgets KF6::KIOFileWidgets KF6::KIOGui KF6::Service KF6::ConfigCore KF6::Notifications Plasma::Plasma Plasma::PlasmaQuick)
