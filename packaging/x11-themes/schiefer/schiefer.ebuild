# Lokales Paket – erzeugt von ~/claude/schiefer/tools/make-dist.sh
EAPI=8

DESCRIPTION="Schiefer: globales Design (Look-and-Feel) und Metapaket für alle Schiefer-Teile"
SRC_URI="schiefer-${PV}.tar.xz"
S="${WORKDIR}/schiefer-${PV}"

LICENSE="GPL-2+"
SLOT="0"
KEYWORDS="amd64 arm64"
RESTRICT="fetch mirror test"

RDEPEND="
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
}

pkg_postinst() {
	elog "Alles auf einmal: Systemeinstellungen › Globales Design › Schiefer"
	elog "(setzt Farben, Plasma-Stil, Icons, Anwendungsstil, Fensterdekoration und Hintergrund)."
	elog "Das GTK-Design separat wählen: Anwendungsstil › GTK-Design › Schiefer"
}
