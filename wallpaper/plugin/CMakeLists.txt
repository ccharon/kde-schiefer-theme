# Schiefer-Muster: Plasma-Hintergrund-Plugin (org.kde.schiefer.backdrop)
#   cmake -B build -G Ninja && cmake --build build
#   test without installing: XDG_DATA_DIRS=<build>/data:... (contains plasma/wallpapers/org.kde.schiefer.backdrop)
cmake_minimum_required(VERSION 3.22)
project(schiefer-backdrop VERSION 0.1 LANGUAGES CXX)  # CXX only so KDEInstallDirs knows the architecture

set(QT_MIN_VERSION 6.6)
set(KF_MIN_VERSION 6.0)
find_package(ECM ${KF_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)

# qsb (Qt Shader Baker) compiles the fragment shader at build time
find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS ShaderTools)
find_package(Plasma REQUIRED)
find_package(KF6 ${KF_MIN_VERSION} REQUIRED COMPONENTS I18n)

set(BACKDROP_ID org.kde.schiefer.backdrop)
set(QSB ${CMAKE_CURRENT_BINARY_DIR}/backdrop.frag.qsb)
add_custom_command(
    OUTPUT ${QSB}
    COMMAND Qt6::qsb --qt6 -o ${QSB} ${CMAKE_CURRENT_SOURCE_DIR}/shaders/backdrop.frag
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/shaders/backdrop.frag
    COMMENT "qsb: backdrop.frag"
    VERBATIM)

# test tree in the build directory: data/plasma/wallpapers/<id> = copy of the package + compiled shader
# (copied because KPackage rejects symlinks leaving the package directory)
set(STAGE ${CMAKE_CURRENT_BINARY_DIR}/data/plasma/wallpapers/${BACKDROP_ID})
file(GLOB_RECURSE PACKAGE_FILES CONFIGURE_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/package/*)
add_custom_command(
    OUTPUT ${STAGE}/contents/shaders/backdrop.frag.qsb
    COMMAND ${CMAKE_COMMAND} -E rm -rf ${STAGE}
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_CURRENT_SOURCE_DIR}/package ${STAGE}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${STAGE}/contents/shaders
    COMMAND ${CMAKE_COMMAND} -E copy ${QSB} ${STAGE}/contents/shaders/backdrop.frag.qsb
    DEPENDS ${QSB} ${PACKAGE_FILES}
    VERBATIM)
add_custom_target(backdrop_shader ALL DEPENDS ${STAGE}/contents/shaders/backdrop.frag.qsb)

plasma_install_package(package ${BACKDROP_ID} wallpapers wallpaper)
install(FILES ${QSB} DESTINATION ${PLASMA_DATA_INSTALL_DIR}/wallpapers/${BACKDROP_ID}/contents/shaders)

ki18n_install(po)
