plasma_add_applet(org.kde.schiefer.endcap
    QML_SOURCES main.qml Bevel.qml config.qml ConfigGeneral.qml
    RESOURCES main.xml
    GENERATE_APPLET_CLASS
)
target_link_libraries(org.kde.schiefer.endcap PRIVATE Plasma::Plasma)
