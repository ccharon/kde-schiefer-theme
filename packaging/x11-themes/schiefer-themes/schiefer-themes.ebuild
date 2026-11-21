# Lokales Paket – erzeugt von ~/claude/schiefer/tools/make-dist.sh
EAPI=8

PYTHON_COMPAT=( python3_{11..14} )
inherit python-any-r1

DESCRIPTION="Schiefer: Farbschemata, Plasma-Stil, GTK-Theme, Mauszeiger, Fensterwechsler und Hintergrund im Motif/CDE-Stil"
SRC_URI="schiefer-${PV}.tar.xz"
S="${WORKDIR}/schiefer-${PV}"

LICENSE="GPL-2+ LGPL-2+"
SLOT="0"
KEYWORDS="amd64 arm64"
RESTRICT="fetch mirror test"

# Das GTK-Theme importiert Breeze-GTK und überschreibt nur das Zeichnen
RDEPEND="kde-plasma/breeze-gtk"
BDEPEND="
	${PYTHON_DEPS}
	$(python_gen_any_dep 'dev-python/pillow[${PYTHON_USEDEP}]')
"

python_check_deps() {
	python_has_version "dev-python/pillow[${PYTHON_USEDEP}]"
}

pkg_nofetch() {
	einfo "Den Quelltarball ${A} erzeugt und kopiert ~/claude/schiefer/tools/install-overlay.sh."
}

src_compile() {
	"${EPYTHON}" plasma/make_plasma_theme.py "${WORKDIR}/plasma/schiefer" || die
	rm -f "${WORKDIR}/plasma/schiefer/.schiefer-generated" || die
	"${EPYTHON}" wallpaper/make_wallpaper_package.py "${WORKDIR}/wallpaper/Schiefer" || die
	# Mauszeiger (reines Python): XCursor 24–96 px + SVG für Wayland, --check prüft Vollständigkeit
	"${EPYTHON}" cursors/make_cursors.py --out "${WORKDIR}/cursors" --check || die
}

src_install() {
	# Paletten Schiefer, Sandstein, Jade, Granit, Basalt (umschalten: schiefer-config palette <Name>)
	insinto /usr/share/color-schemes
	doins colors/*.colors

	insinto /usr/share/plasma/desktoptheme
	doins -r "${WORKDIR}/plasma/schiefer"

	insinto /usr/share/themes
	doins -r gtk/Schiefer

	insinto /usr/share/icons
	doins -r "${WORKDIR}/cursors/Schiefer"

	# Fensterwechsler (Alt+Tab) für KWin
	insinto /usr/share/kwin-wayland/tabbox
	doins -r kwin/tabbox/schiefer

	insinto /usr/share/wallpapers
	doins -r "${WORKDIR}/wallpaper/Schiefer"

	# Muster und Skript für pixelgenaue Hintergründe in jeder Auflösung
	insinto /usr/share/schiefer/wallpaper
	doins -r wallpaper/tiles
	exeinto /usr/share/schiefer/wallpaper
	doexe wallpaper/apply.sh
	dosym -r /usr/share/schiefer/wallpaper/apply.sh /usr/bin/schiefer-wallpaper
}

pkg_postinst() {
	elog "GTK-Theme aktivieren: Systemeinstellungen › Anwendungsstil › GTK-Design › Schiefer"
	elog "Mauszeiger: Systemeinstellungen › Mauszeiger › Schiefer"
	elog "Fensterwechsler: Systemeinstellungen › Fensterverwaltung › Fensterwechsel › Schiefer"
	elog "Bild-Hintergrund pixelgenau für jede Auflösung: schiefer-wallpaper [muster]"
	elog "(Muster je Arbeitsfläche: Paket x11-themes/schiefer-backdrop)"
}
