plasma_add_applet(org.kde.schiefer.console
    QML_SOURCES main.qml ${DOCK_COMMON}/Bevel.qml ${DOCK_COMMON}/FrameTint.qml ${DOCK_COMMON}/MotifArrow.qml TaskButton.qml config.qml ConfigGeneral.qml
    CPP_SOURCES ${DOCK_COMMON}/schieferhelper.cpp ${DOCK_COMMON}/schieferscheme.cpp
    RESOURCES main.xml
    GENERATE_APPLET_CLASS
)
target_link_libraries(org.kde.schiefer.console PRIVATE Qt6::Quick KF6::KirigamiPlatform Qt6::DBus KF6::KIOWidgets KF6::KIOGui KF6::Service KF6::ConfigCore KF6::Notifications)
# C++ strings (i18n) in the same translation domain as the applet's QML strings
target_link_libraries(org.kde.schiefer.console PRIVATE KF6::I18n)
target_compile_definitions(org.kde.schiefer.console PRIVATE TRANSLATION_DOMAIN="plasma_applet_org.kde.schiefer.console")
