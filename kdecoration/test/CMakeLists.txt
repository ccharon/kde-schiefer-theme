# Eigenständiger Test der Dekoration (nicht Teil des Pakets):
#   cmake -S kdecoration/test -B kdecoration/test/build -G Ninja && cmake --build kdecoration/test/build
#   kdecoration/test/build/decotest          (prüft kdecoration/build/bin/schiefer.so)
# mock*.cpp/h: aus kdecoration-6.7.6/autotests (LGPL), Includes auf installierte Header umgestellt,
# MockSettings mit Menüknopf links und Schließen rechts.
cmake_minimum_required(VERSION 3.16)
project(schiefer-decotest)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Core Gui Test)
find_package(KF6CoreAddons REQUIRED)
find_package(KDecoration3 REQUIRED)
add_executable(decotest decotest.cpp mockbridge.cpp mockbutton.cpp mockwindow.cpp mockdecoration.cpp mocksettings.cpp)
target_compile_definitions(decotest PRIVATE SCHIEFER_DECO_PLUGIN_DEFAULT="${CMAKE_CURRENT_SOURCE_DIR}/../build/bin/schiefer.so")
target_link_libraries(decotest Qt6::Gui Qt6::Test KF6::CoreAddons KDecoration3::KDecoration KDecoration3::KDecoration3Private)
