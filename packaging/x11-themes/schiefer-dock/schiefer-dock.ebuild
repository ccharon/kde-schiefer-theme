# Lokales Paket – erzeugt von ~/claude/schiefer/tools/make-dist.sh
EAPI=8

inherit cmake

DESCRIPTION="Schiefer-Dock: Plasma-Widgets im Stil des CDE-Frontpanels"
SRC_URI="schiefer-${PV}.tar.xz"
S="${WORKDIR}/schiefer-${PV}/dock"

LICENSE="GPL-2+"
SLOT="0"
KEYWORDS="amd64 arm64"
# Quelltarball liegt nur lokal vor (tools/install-overlay.sh legt ihn in DISTDIR)
RESTRICT="fetch mirror test"

# libplasma:6= sorgt für einen Neubau, wenn sich die Plasma-ABI ändert (Applets linken gegen libplasma)
DEPEND="
	dev-qt/qtbase:6=[dbus,gui]
	dev-qt/qtdeclarative:6
	kde-frameworks/kconfig:6
	kde-frameworks/kcoreaddons:6
	kde-frameworks/ki18n:6
	kde-frameworks/kio:6
	kde-frameworks/knotifications:6
	kde-frameworks/kservice:6
	kde-plasma/libplasma:6=
"
# zur Laufzeit: QML-Module (Kirigami, KItemModels, KCMUtils, DragAndDrop, TaskManager)
# und der Plasma-Systemabschnitt für die Statuskacheln
RDEPEND="${DEPEND}
	kde-frameworks/kcmutils:6
	kde-frameworks/kdeclarative:6
	kde-frameworks/kirigami:6
	kde-frameworks/kitemmodels:6
	kde-plasma/plasma-workspace:6
"
BDEPEND="kde-frameworks/extra-cmake-modules:0"

pkg_nofetch() {
	einfo "Den Quelltarball ${A} erzeugt und kopiert ~/claude/schiefer/tools/install-overlay.sh."
}

src_configure() {
	local mycmakeargs=( -DKDE_INSTALL_USE_QT_SYS_PATHS=ON -DBUILD_TESTING=OFF )
	cmake_src_configure
}

src_install() {
	cmake_src_install
	# Plasma-Skripte zum Aufbau der Leisten
	insinto /usr/share/schiefer/dock
	doins layout.js add-endcaps.js
}

pkg_postinst() {
	elog "Nach Installation oder Update: systemctl --user restart plasma-plasmashell"
	elog
	elog "Leisten aufbauen (Dock unten, Icon Box links, Statuskacheln rechts oben)."
	elog "ACHTUNG: entfernt vorhandene Leisten unten, links und rechts!"
	elog "  qdbus6 org.kde.plasmashell /PlasmaShell evaluateScript \"\$(cat ${EPREFIX}/usr/share/schiefer/dock/layout.js)\""
	elog
	elog "Nur die Abschlussstücke in ein vorhandenes Dock einfügen:"
	elog "  qdbus6 org.kde.plasmashell /PlasmaShell evaluateScript \"\$(cat ${EPREFIX}/usr/share/schiefer/dock/add-endcaps.js)\""
}
