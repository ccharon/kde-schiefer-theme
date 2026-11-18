cmake_minimum_required(VERSION 3.16)
project(schiefer-decoration VERSION 0.1)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(ECM 6.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
set(QT_MAJOR_VERSION 6)
include(KDEInstallDirs6)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

find_package(Qt6 6.6 REQUIRED COMPONENTS Core Gui DBus)
find_package(KF6 6.0 REQUIRED COMPONENTS CoreAddons Config)
find_package(KDecoration3 REQUIRED)

add_library(schieferdecoration MODULE retrodecoration.cpp)
set_target_properties(schieferdecoration PROPERTIES OUTPUT_NAME schiefer)
target_link_libraries(schieferdecoration PRIVATE
    Qt6::Core Qt6::Gui Qt6::DBus KF6::CoreAddons KF6::ConfigCore KF6::ConfigGui KDecoration3::KDecoration)

install(TARGETS schieferdecoration DESTINATION ${KDE_INSTALL_PLUGINDIR}/${KDECORATION_PLUGIN_DIR})
