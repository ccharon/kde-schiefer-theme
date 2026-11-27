#!/bin/bash
# dracut module: writes the Schiefer boot screen script with the details of this machine and
# the kernel being built (Plymouth reads it from ScriptFile in schiefer.plymouth) and copies it
# into the initramfs. Active only while "schiefer" is the default Plymouth theme.

SCHIEFER_INFO=/usr/libexec/schiefer/schiefer-plymouth-info
SCHIEFER_SCRIPT=/var/lib/schiefer/plymouth/schiefer.script
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
        --out "${dracutsysrootdir-}$SCHIEFER_SCRIPT"; then
        dwarn "schiefer-plymouth: could not write $SCHIEFER_SCRIPT"
    fi
    inst_simple "$SCHIEFER_SCRIPT"
    # Plymouth's progress estimate: without the times of the last boot it assumes 60 s and slows the
    # bar to a crawl at about 27 %. dracut's plymouth module leaves the file out, so the whole
    # initramfs part of the boot would run without it.
    [[ -r "${dracutsysrootdir-}$PLYMOUTH_BOOT_DURATION" ]] && inst_simple "$PLYMOUTH_BOOT_DURATION"
}
