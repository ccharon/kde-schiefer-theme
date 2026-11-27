# Standalone test of the decoration (not part of the package):
#   cmake -S kdecoration/test -B kdecoration/test/build -G Ninja && cmake --build kdecoration/test/build
#   kdecoration/test/build/decotest          (tests kdecoration/build/bin/schiefer.so)
# mock*.cpp/h: from kdecoration-6.7.6/autotests (LGPL), includes switched to the installed headers,
# MockSettings with the menu button on the left and close on the right.
cmake_minimum_required(VERSION 3.16)
project(schiefer-decotest)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Core Gui Test)
find_package(KF6CoreAddons REQUIRED)
find_package(KF6Config REQUIRED)
find_package(KDecoration3 REQUIRED)
add_executable(decotest decotest.cpp mockbridge.cpp mockbutton.cpp mockwindow.cpp mockdecoration.cpp mocksettings.cpp)
target_compile_definitions(decotest PRIVATE SCHIEFER_DECO_PLUGIN_DEFAULT="${CMAKE_CURRENT_SOURCE_DIR}/../build/bin/schiefer.so")
# KConfigGui registers the QColor reading of KConfig (as in KWin); --no-as-needed keeps it loaded
target_link_libraries(decotest "-Wl,--no-as-needed" Qt6::Gui Qt6::Test KF6::CoreAddons KF6::ConfigGui KDecoration3::KDecoration KDecoration3::KDecoration3Private)
