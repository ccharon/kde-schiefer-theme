#!/bin/bash
# dracut module: writes the Schiefer boot screen script with the details of this machine and
# the kernel being built (Plymouth reads it from ScriptFile in schiefer.plymouth) and copies it
# into the initramfs. Active only while "schiefer" is the default Plymouth theme.

SCHIEFER_INFO=/usr/libexec/schiefer/schiefer-plymouth-info
SCHIEFER_SCRIPT=/var/lib/schiefer/plymouth/schiefer.script

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
}
