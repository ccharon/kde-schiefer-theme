plasma_add_applet(org.kde.schiefer.endcap
    QML_SOURCES main.qml Bevel.qml FrameTint.qml config.qml ConfigGeneral.qml
    CPP_SOURCES schieferscheme.cpp
    RESOURCES main.xml
    GENERATE_APPLET_CLASS
)
target_link_libraries(org.kde.schiefer.endcap PRIVATE Qt6::Quick KF6::KirigamiPlatform Plasma::Plasma KF6::ConfigCore)
