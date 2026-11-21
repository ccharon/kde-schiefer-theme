plasma_add_applet(org.kde.schiefer.iconbox
    QML_SOURCES main.qml Bevel.qml FrameTint.qml PanelFit.qml MotifArrow.qml Section.qml WindowRow.qml WindowIcon.qml config.qml ConfigGeneral.qml
    CPP_SOURCES schieferhelper.cpp schieferscheme.cpp
    RESOURCES main.xml
    GENERATE_APPLET_CLASS
)
target_link_libraries(org.kde.schiefer.iconbox PRIVATE Qt6::Quick KF6::KirigamiPlatform Qt6::DBus KF6::KIOWidgets KF6::KIOGui KF6::Service KF6::ConfigCore KF6::Notifications)
# C++-Texte (i18n) in derselben Übersetzungsdomäne wie die QML-Texte des Applets
target_link_libraries(org.kde.schiefer.iconbox PRIVATE KF6::I18n)
target_compile_definitions(org.kde.schiefer.iconbox PRIVATE TRANSLATION_DOMAIN="plasma_applet_org.kde.schiefer.iconbox")
