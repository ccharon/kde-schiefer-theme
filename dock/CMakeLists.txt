# Schiefer dock: Plasma widgets in the style of the CDE front panel
cmake_minimum_required(VERSION 3.22)
project(schiefer-dock VERSION 0.2)

set(QT_MIN_VERSION 6.6)
set(KF_MIN_VERSION 6.0)
find_package(ECM ${KF_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS Core Gui Qml Quick DBus)
find_package(KF6 ${KF_MIN_VERSION} REQUIRED COMPONENTS CoreAddons KIO Notifications Service I18n Config)
find_package(KF6KirigamiPlatform ${KF_MIN_VERSION} REQUIRED)
find_package(Plasma REQUIRED)
find_package(PlasmaQuick REQUIRED)

# Motif color formula (shared with kstyle/ and kdecoration/)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../common)

add_subdirectory(drawer)
add_subdirectory(console)
add_subdirectory(iconbox)
add_subdirectory(tiles)
add_subdirectory(endcap)

ki18n_install(po)
