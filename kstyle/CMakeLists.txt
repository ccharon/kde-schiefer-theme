cmake_minimum_required(VERSION 3.16)
project(schiefer-style VERSION 0.1)
# Fork des Breeze-Widget-Stils (kde-plasma/breeze 6.7.6) – Zeichenroutinen im Motif/CDE-Stil.

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(ECM 6.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
set(QT_MAJOR_VERSION 6)
set(KDE_COMPILERSETTINGS_LEVEL "5.82")
include(KDEInstallDirs6)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMQtDeclareLoggingCategory)

find_package(Qt6 6.6 REQUIRED COMPONENTS Core Gui Widgets DBus Quick)
find_package(KF6 6.0 REQUIRED COMPONENTS CoreAddons Config GuiAddons IconThemes WindowSystem ColorScheme)
find_package(KF6FrameworkIntegration 6.0 CONFIG)

set(BREEZE_HAVE_QTQUICK ON)
set(BREEZE_HAVE_KSTYLE ${KF6FrameworkIntegration_FOUND})
set(HAVE_QTDBUS ON)
configure_file(config-breeze.h.cmake ${CMAKE_CURRENT_BINARY_DIR}/config-breeze.h)

include_directories(animations debug common ${CMAKE_CURRENT_BINARY_DIR})
# Schiefer: gemeinsamer Farbkern (Motif-Formel), nur Header
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../common)

set(SRCS
    animations/breezeanimation.cpp
    animations/breezeanimations.cpp
    animations/breezeanimationdata.cpp
    animations/breezebaseengine.cpp
    animations/breezebusyindicatordata.cpp
    animations/breezebusyindicatorengine.cpp
    animations/breezedialdata.cpp
    animations/breezedialengine.cpp
    animations/breezeenabledata.cpp
    animations/breezegenericdata.cpp
    animations/breezeheaderviewdata.cpp
    animations/breezeheaderviewengine.cpp
    animations/breezescrollbardata.cpp
    animations/breezescrollbarengine.cpp
    animations/breezespinboxengine.cpp
    animations/breezespinboxdata.cpp
    animations/breezestackedwidgetdata.cpp
    animations/breezestackedwidgetengine.cpp
    animations/breezetabbarengine.cpp
    animations/breezetabbardata.cpp
    animations/breezetoolboxengine.cpp
    animations/breezetransitiondata.cpp
    animations/breezetransitionwidget.cpp
    animations/breezewidgetstateengine.cpp
    animations/breezewidgetstatedata.cpp
    debug/breezewidgetexplorer.cpp
    common/breezeboxshadowrenderer.cpp
    breezeaddeventfilter.cpp
    breezeblurhelper.cpp
    breezeframeshadow.cpp
    breezehelper.cpp
    breezemdiwindowshadow.cpp
    breezemnemonics.cpp
    breezepropertynames.cpp
    breezeshadowhelper.cpp
    breezesplitterproxy.cpp
    breezestyle.cpp
    breezestyleplugin.cpp
    breezetileset.cpp
    breezewindowmanager.cpp
    breezetoolsareamanager.cpp
)
kconfig_add_kcfg_files(SRCS kdeco/breezesettings.kcfgc)
kconfig_add_kcfg_files(SRCS breezestyleconfigdata.kcfgc)

add_library(schiefer6 MODULE ${SRCS})
ecm_qt_declare_logging_category(schiefer6 HEADER breeze_logging.h IDENTIFIER BREEZE
    CATEGORY_NAME schiefer6 DEFAULT_SEVERITY Warning)

target_link_libraries(schiefer6
    Qt6::Core Qt6::Gui Qt6::Widgets Qt6::DBus Qt6::Quick
    KF6::CoreAddons KF6::ConfigCore KF6::ConfigGui KF6::GuiAddons KF6::IconThemes
    KF6::WindowSystem KF6::ColorScheme)
if(KF6FrameworkIntegration_FOUND)
    target_link_libraries(schiefer6 KF6::Style)
endif()

install(TARGETS schiefer6 DESTINATION ${KDE_INSTALL_QTPLUGINDIR}/styles/)
install(FILES schiefer.themerc DESTINATION ${KDE_INSTALL_DATADIR}/kstyle/themes)

# Test-Galerie (wird nicht installiert; im Ebuild abgeschaltet)
option(BUILD_GALLERY "Testgalerie für render.sh bauen" ON)
if(BUILD_GALLERY)
    add_executable(retrogallery test/gallery.cpp)
    target_link_libraries(retrogallery Qt6::Widgets)
endif()
