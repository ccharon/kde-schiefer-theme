# Lokales Paket – erzeugt von ~/claude/schiefer/tools/make-dist.sh
EAPI=8

PYTHON_COMPAT=( python3_{11..14} )
inherit python-single-r1

DESCRIPTION="Schiefer: globales Design (Look-and-Feel), schiefer-config und Metapaket für alle Schiefer-Teile"
SRC_URI="schiefer-${PV}.tar.xz"
S="${WORKDIR}/schiefer-${PV}"

LICENSE="GPL-2+"
SLOT="0"
KEYWORDS="amd64 arm64"
RESTRICT="fetch mirror test"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

# schiefer-config ruft kreadconfig6/kwriteconfig6, qdbus6 und plasma-apply-* auf
RDEPEND="
	${PYTHON_DEPS}
	dev-qt/qttools:6[qdbus]
	kde-frameworks/kconfig:6
	kde-plasma/plasma-workspace:6
	~x11-themes/schiefer-backdrop-${PV}
	~x11-themes/schiefer-dock-${PV}
	~x11-themes/schiefer-icons-${PV}
	~x11-themes/schiefer-kde-${PV}
	~x11-themes/schiefer-themes-${PV}
"

pkg_nofetch() {
	einfo "Den Quelltarball ${A} erzeugt und kopiert ~/claude/schiefer/tools/install-overlay.sh."
}

src_install() {
	insinto /usr/share/plasma/look-and-feel
	doins -r lookandfeel/schiefer.desktop

	python_doscript tools/schiefer-config
}

pkg_postinst() {
	elog "Alles auf einmal: Systemeinstellungen › Globales Design › Schiefer"
	elog "(setzt Farben, Plasma-Stil, Icons, Anwendungsstil, Fensterdekoration und Hintergrund)."
	elog "Das GTK-Design separat wählen: Anwendungsstil › GTK-Design › Schiefer"
	elog
	elog "Einzelne Motif-Eigenheiten ein- und ausschalten, Paletten wechseln:"
	elog "  schiefer-config liste"
	elog "  schiefer-config standard        (alle Schalter auf die Schiefer-Vorgabe, z. B. nach dem globalen Design)"
	elog "  schiefer-config palette basalt  (Paletten: schiefer, sandstein, jade, granit, basalt)"
}
