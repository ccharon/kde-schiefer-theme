# Lokales Paket – erzeugt von ~/claude/schiefer/tools/make-dist.sh
EAPI=8

inherit cmake

DESCRIPTION="Schiefer: Fensterdekoration und Qt-Widget-Stil im Motif/CDE-Stil (Fork von Breeze)"
SRC_URI="schiefer-${PV}.tar.xz"
S="${WORKDIR}/schiefer-${PV}"

LICENSE="GPL-2+"
SLOT="0"
KEYWORDS="amd64 arm64"
# Quelltarball liegt nur lokal vor (tools/install-overlay.sh legt ihn in DISTDIR)
RESTRICT="fetch mirror test"

# qtbase:6= und kdecoration:6= sorgen für automatischen Neubau bei ABI-Änderungen
DEPEND="
	dev-qt/qtbase:6=[dbus,gui,widgets]
	dev-qt/qtdeclarative:6
	kde-frameworks/frameworkintegration:6
	kde-frameworks/kcolorscheme:6
	kde-frameworks/kconfig:6
	kde-frameworks/kcoreaddons:6
	kde-frameworks/kguiaddons:6
	kde-frameworks/kiconthemes:6
	kde-frameworks/kwindowsystem:6
	kde-plasma/kdecoration:6=
"
RDEPEND="${DEPEND}"
BDEPEND="kde-frameworks/extra-cmake-modules:0"

pkg_nofetch() {
	einfo "Den Quelltarball ${A} erzeugt und kopiert ~/claude/schiefer/tools/install-overlay.sh."
}

# Zwei eigenständige CMake-Projekte (kdecoration, kstyle) – jeweils vorbereiten, bauen, installieren
src_prepare() {
	default
	local c
	for c in kdecoration kstyle; do
		CMAKE_USE_DIR="${S}/${c}" BUILD_DIR="${WORKDIR}/build-${c}" cmake_prepare
	done
}

src_configure() {
	local mycmakeargs=( -DKDE_INSTALL_USE_QT_SYS_PATHS=ON -DBUILD_TESTING=OFF )
	CMAKE_USE_DIR="${S}/kdecoration" BUILD_DIR="${WORKDIR}/build-kdecoration" cmake_src_configure
	mycmakeargs+=( -DBUILD_GALLERY=OFF )
	CMAKE_USE_DIR="${S}/kstyle" BUILD_DIR="${WORKDIR}/build-kstyle" cmake_src_configure
}

src_compile() {
	local c
	for c in kdecoration kstyle; do
		BUILD_DIR="${WORKDIR}/build-${c}" cmake_src_compile
	done
}

src_install() {
	local c
	for c in kdecoration kstyle; do
		BUILD_DIR="${WORKDIR}/build-${c}" cmake_src_install
	done
}

pkg_postinst() {
	elog "Fensterdekoration: Systemeinstellungen › Fensterdekorationen › Schiefer"
	elog "Anwendungsstil:    Systemeinstellungen › Anwendungsstil › Schiefer"
	elog "Nach einem Update der Dekoration: kwin_wayland --replace & (oder neu anmelden)"
}
