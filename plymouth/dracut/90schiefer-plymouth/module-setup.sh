#!/bin/bash
# dracut module: writes the Schiefer boot screen script with the details of this machine and
# the kernel being built (Plymouth reads it from ScriptFile in schiefer.plymouth) and the images of
# the system palette (ImageDir), and copies both into the initramfs. Active only while "schiefer"
# is the default Plymouth theme.

SCHIEFER_INFO=/usr/libexec/schiefer/schiefer-plymouth-info
SCHIEFER_SCRIPT=/var/lib/schiefer/plymouth/schiefer.script
SCHIEFER_IMAGES=/var/lib/schiefer/plymouth/images
PLYMOUTH_BOOT_DURATION=/var/lib/plymouth/boot-duration

check() {
    [[ -x "${dracutsysrootdir-}$SCHIEFER_INFO" ]] || return 1
    require_binaries plymouth-set-default-theme || return 1
    [[ "$(plymouth-set-default-theme 2>/dev/null)" == schiefer ]] || return 1
    return 0
}

depends() {
    echo plymouth
}

install() {
    if ! "${dracutsysrootdir-}$SCHIEFER_INFO" --kernel "${kernel:-$(uname -r)}" \
        --template "${dracutsysrootdir-}/usr/share/plymouth/themes/schiefer/schiefer.script.in" \
        --palettes "${dracutsysrootdir-}/usr/share/schiefer/plymouth" \
        --out "${dracutsysrootdir-}$SCHIEFER_SCRIPT"; then
        dwarn "schiefer-plymouth: could not write $SCHIEFER_SCRIPT"
    fi
    inst_simple "$SCHIEFER_SCRIPT"
    # The plymouth module ran first and copied ImageDir as it was before this run, possibly in
    # another palette.
    rm -rf "${initdir}$SCHIEFER_IMAGES"
    inst_dir "$SCHIEFER_IMAGES"
    local f
    for f in "${dracutsysrootdir-}$SCHIEFER_IMAGES"/*.png; do
        [[ -e "$f" ]] && inst_simple "${f#"${dracutsysrootdir-}"}"
    done
    # Plymouth's progress estimate: without the times of the last boot it assumes 60 s and slows the
    # bar to a crawl at about 27 %. dracut's plymouth module leaves the file out, so the whole
    # initramfs part of the boot would run without it.
    # plymouthd writes the file with the decimal separator of the system locale ("0,159:unit" for
    # de_DE), but in the initramfs it has no locale data and stays in the C locale, where fscanf
    # stops at the comma and drops the whole file. The copy in the initramfs gets decimal points.
    local src="${dracutsysrootdir-}$PLYMOUTH_BOOT_DURATION"
    if [[ -r "$src" ]]; then
        inst_dir "${PLYMOUTH_BOOT_DURATION%/*}"
        # never write through a link another module may have put there (it could point to the host file)
        rm -f "${initdir}$PLYMOUTH_BOOT_DURATION"
        LC_ALL=C sed -E 's/^([0-9]+),([0-9]+):/\1.\2:/' "$src" > "${initdir}$PLYMOUTH_BOOT_DURATION"
    fi
}
