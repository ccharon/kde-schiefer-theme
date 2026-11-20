plasma_add_applet(org.kde.schiefer.iconbox
    QML_SOURCES main.qml Bevel.qml MotifArrow.qml Section.qml WindowRow.qml WindowIcon.qml config.qml ConfigGeneral.qml
    CPP_SOURCES schieferhelper.cpp
    RESOURCES main.xml
    GENERATE_APPLET_CLASS
)
target_link_libraries(org.kde.schiefer.iconbox PRIVATE Qt6::DBus KF6::KIOWidgets KF6::KIOGui KF6::Service KF6::ConfigCore KF6::Notifications)
