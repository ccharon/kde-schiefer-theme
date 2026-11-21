# Lokales Paket – erzeugt von ~/claude/schiefer/tools/make-dist.sh
EAPI=8

PYTHON_COMPAT=( python3_{11..14} )
inherit multiprocessing python-any-r1 xdg

DESCRIPTION="Schiefer: Breeze-Icons in gedämpften CDE/Motif-Farben (SVG), beim Bauen aus breeze-icons erzeugt"
SRC_URI="schiefer-${PV}.tar.xz"
S="${WORKDIR}/schiefer-${PV}"

LICENSE="LGPL-3"
SLOT="0"
KEYWORDS="amd64 arm64"
RESTRICT="fetch mirror test"

# Die Icons werden beim Bauen aus breeze-icons erzeugt und sind danach eine Momentaufnahme.
# Nach breeze-icons-Updates sollte das Paket neu gebaut werden: emerge -1 schiefer-icons
# breeze-icons hat den Subslot 6/<Frameworks-Minor> (frameworks.kde.org.eclass); der Slot-Operator
# ":6=" in RDEPEND lässt Portage dieses Paket bei jedem Minor-Sprung automatisch mitbauen.
# (In BDEPEND ist ":=" nicht erlaubt, daher dort ohne Operator.)
RDEPEND="kde-frameworks/breeze-icons:6="
BDEPEND="
	${PYTHON_DEPS}
	kde-frameworks/breeze-icons:6
	$(python_gen_any_dep '
		dev-python/numpy[${PYTHON_USEDEP}]
	')
"

python_check_deps() {
	python_has_version "dev-python/numpy[${PYTHON_USEDEP}]"
}

pkg_nofetch() {
	einfo "Den Quelltarball ${A} erzeugt und kopiert ~/claude/schiefer/tools/install-overlay.sh."
}

src_compile() {
	einfo "Färbe die Icons aus /usr/share/icons/breeze um …"
	"${EPYTHON}" make_theme.py --src "${EPREFIX}/usr/share/icons/breeze" \
		--out "${WORKDIR}/icons/schiefer" --name Schiefer -j "$(makeopts_jobs)" || die
	# make_theme.py beendet sich bei Fehlern mit Exit-Code 1 (dann bricht || die den Bau ab)
	rm -f "${WORKDIR}/icons/schiefer/.schiefer-generated" || die
}

src_install() {
	dodir /usr/share/icons
	# cp -a erhält die Symlinks des Themes
	cp -a "${WORKDIR}/icons/schiefer" "${ED}/usr/share/icons/" || die
}

pkg_preinst() {
	# Bis 0.3 waren Größenordner wie 16@2x echte Ordner, jetzt sind es Symlinks (16@2x -> 16) wie in Breeze.
	# Portage ersetzt keinen Ordner durch einen Symlink: der Symlink landete als "16@2x.backup.0000" daneben
	# und der alte Ordner blieb leer zurück – bei jeder Neuinstallation wieder. Leere Reste hier entfernen.
	local l rel t
	while IFS= read -r -d '' l; do
		[[ -d ${l} ]] || continue          # nur Ordner-Symlinks
		rel=${l#"${ED}"}
		t=${EROOT%/}${rel}
		rm -f "${t}".backup.[0-9][0-9][0-9][0-9]
		if [[ -d ${t} && ! -L ${t} ]]; then
			rmdir "${t}" 2>/dev/null || ewarn "Nicht leer, bitte von Hand entfernen: ${t}"
		fi
	done < <(find "${ED}/usr/share/icons/schiefer" -type l -print0)
}

pkg_postinst() {
	xdg_pkg_postinst
	elog "Schiefer-Icons sind eine Momentaufnahme von breeze-icons."
	elog "Nach Updates von kde-frameworks/breeze-icons bitte neu bauen:"
	elog "  emerge -1 schiefer-icons"
}
