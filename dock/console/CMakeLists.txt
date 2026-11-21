plasma_add_applet(org.kde.schiefer.console
    QML_SOURCES main.qml Bevel.qml MotifArrow.qml TaskButton.qml config.qml ConfigGeneral.qml
    CPP_SOURCES schieferhelper.cpp schieferscheme.cpp
    RESOURCES main.xml
    GENERATE_APPLET_CLASS
)
target_link_libraries(org.kde.schiefer.console PRIVATE Qt6::DBus KF6::KIOWidgets KF6::KIOGui KF6::Service KF6::ConfigCore KF6::Notifications)
# C++-Texte (i18n) in derselben Übersetzungsdomäne wie die QML-Texte des Applets
target_link_libraries(org.kde.schiefer.console PRIVATE KF6::I18n)
target_compile_definitions(org.kde.schiefer.console PRIVATE TRANSLATION_DOMAIN="plasma_applet_org.kde.schiefer.console")
