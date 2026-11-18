# Lokales Paket – erzeugt von ~/claude/schiefer/tools/make-dist.sh
EAPI=8

PYTHON_COMPAT=( python3_{11..14} )
inherit multiprocessing python-any-r1 xdg

DESCRIPTION="Schiefer: Icon-Theme im CDE/Motif-Stil, beim Bauen aus breeze-icons erzeugt"
SRC_URI="schiefer-${PV}.tar.xz"
S="${WORKDIR}/schiefer-${PV}"

LICENSE="LGPL-3"
SLOT="0"
KEYWORDS="amd64 arm64"
RESTRICT="fetch mirror test"

RDEPEND="kde-frameworks/breeze-icons:6"
BDEPEND="
	${PYTHON_DEPS}
	${RDEPEND}
	gnome-base/librsvg
	$(python_gen_any_dep '
		dev-python/numpy[${PYTHON_USEDEP}]
		dev-python/pillow[${PYTHON_USEDEP}]
	')
"

python_check_deps() {
	python_has_version "dev-python/numpy[${PYTHON_USEDEP}]" "dev-python/pillow[${PYTHON_USEDEP}]"
}

pkg_nofetch() {
	einfo "Den Quelltarball ${A} erzeugt und kopiert ~/claude/schiefer/tools/install-overlay.sh."
}

src_compile() {
	einfo "Erzeuge Icons aus /usr/share/icons/breeze (dauert einige Minuten) …"
	"${EPYTHON}" make_theme.py --src "${EPREFIX}/usr/share/icons/breeze" \
		--out "${WORKDIR}/icons/schiefer" --name Schiefer -j "$(makeopts_jobs)" || die
	rm -f "${WORKDIR}/icons/schiefer/.schiefer-generated" || die
}

src_install() {
	dodir /usr/share/icons
	# cp -a erhält die Symlinks des Themes
	cp -a "${WORKDIR}/icons/schiefer" "${ED}/usr/share/icons/" || die
}
