# Lokales Paket – erzeugt von ~/claude/schiefer/tools/make-dist.sh
EAPI=8

PYTHON_COMPAT=( python3_{11..14} )
inherit python-single-r1

DESCRIPTION="Schiefer: globales Design (Startbild, Abmelden), Sperrbildschirm, SDDM-Anmeldung, schiefer-config, Metapaket"
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

src_prepare() {
	default
	# gemeinsamer Motif-Baukasten liegt im Quellbaum als Symlink vor; installiert wird je eine Kopie
	# (KPackage und SDDM lesen nur innerhalb ihres Verzeichnisses)
	local d
	for d in lookandfeel/schiefer.desktop/contents greeter/sddm/schiefer greeter/lockscreen; do
		rm "${d}/kit" || die
		cp -r greeter/kit "${d}/kit" || die
	done
	# Zeile unter dem Rechnernamen bei der Anmeldung: Name des Systems
	local os
	os=$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME}")
	sed -i "s|^subtitle=.*|subtitle=${os//|/}|" greeter/sddm/schiefer/theme.conf || die
}

src_install() {
	insinto /usr/share/plasma/look-and-feel
	doins -r lookandfeel/schiefer.desktop

	insinto /usr/share/sddm/themes
	doins -r greeter/sddm/schiefer

	insinto /usr/share/schiefer
	doins -r greeter/lockscreen

	insinto /etc/xdg/plasma-workspace/env
	doins greeter/schiefer-sperrbildschirm.sh

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
	elog
	elog "Sperrbildschirm (je Benutzer):  schiefer-config sperrbildschirm an"
	elog "Anmeldung (SDDM, für alle):      Systemeinstellungen › Anmeldebildschirm (SDDM) › Schiefer"
	elog "  oder /etc/sddm.conf.d/…: [Theme] Current=schiefer"
}
