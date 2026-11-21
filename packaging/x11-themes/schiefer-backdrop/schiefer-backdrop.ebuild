# Lokales Paket – erzeugt von ~/claude/schiefer/tools/make-dist.sh
EAPI=8

inherit cmake

DESCRIPTION="Schiefer-Muster: Plasma-Hintergrund mit Muster und Farbe je Arbeitsfläche (CDE)"
SRC_URI="schiefer-${PV}.tar.xz"
S="${WORKDIR}/schiefer-${PV}/wallpaper/plugin"

LICENSE="GPL-2+"
SLOT="0"
KEYWORDS="amd64 arm64"
# Quelltarball liegt nur lokal vor (tools/install-overlay.sh legt ihn in DISTDIR)
RESTRICT="fetch mirror test"

# reines QML-Paket mit einem Shader (qsb beim Bauen); libplasma nur für die CMake-Makros
DEPEND="kde-plasma/libplasma:6"
RDEPEND="
	dev-qt/qtdeclarative:6
	kde-frameworks/kdeclarative:6
	kde-frameworks/kirigami:6
	kde-plasma/plasma-workspace:6
"
BDEPEND="
	dev-qt/qtshadertools:6
	kde-frameworks/extra-cmake-modules:0
"

pkg_nofetch() {
	einfo "Den Quelltarball ${A} erzeugt und kopiert ~/claude/schiefer/tools/install-overlay.sh."
}

src_configure() {
	local mycmakeargs=( -DKDE_INSTALL_USE_QT_SYS_PATHS=ON -DBUILD_TESTING=OFF )
	cmake_src_configure
}

pkg_postinst() {
	elog "Hintergrund einstellen: Rechtsklick auf die Arbeitsfläche › Arbeitsfläche einrichten ›"
	elog "Hintergrundart „Schiefer-Muster“ – oder: schiefer-config muster-hintergrund an"
	elog "Nach Installation oder Update: systemctl --user restart plasma-plasmashell"
}
