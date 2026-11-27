#!/bin/bash
# Captures the boot screen in isolation: Plymouth with its x11 renderer in its own KWin session,
# as namespace root (bwrap) with a private /dev, /run and network, so neither the real Plymouth,
# the graphics card nor the consoles are touched.
#   PLY_PREFIX=<plymouth 22 build with --enable-tracing> plymouth/test-plymouth.sh out.png [scene]
#   scenes: boot (default: units of this machine), password (ZFS passphrase prompt), shutdown
#   BR_WIDTH/BR_HEIGHT: screen size (default 1600x1000), BR_MM: its height in mm (default 0: scale by pixels)
#   PALETTE: palette of the images (default: schiefer)
# The distribution build of Plymouth works too but logs nothing; PLY_PREFIX=/usr for that.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$(realpath -m "$1")"; SCENE="${2:-boot}"
P="${PLY_PREFIX:?set PLY_PREFIX to a Plymouth 22 installation prefix}"
T="$(mktemp -d)"; trap '[ -n "${KEEP:-}" ] && echo "$T" >&2 || rm -rf "$T"' EXIT
TH="$T/themes/schiefer"; mkdir -p "$TH"
"$HERE/schiefer-plymouth-info" --template "$HERE/schiefer/schiefer.script.in" --out "$TH/schiefer.script" \
    --screen-mm "${BR_MM:-0}" --palettes "$HERE/palettes" --palette "${PALETTE:-schiefer}"
sed -e "s|^ImageDir=.*|ImageDir=$TH/images|" -e "s|^ScriptFile=.*|ScriptFile=$TH/schiefer.script|" \
    "$HERE/schiefer/schiefer.plymouth" > "$TH/schiefer.plymouth"
MODE=boot; [ "$SCENE" = shutdown ] && MODE=shutdown
# units of this machine in start order as the status feed
systemctl list-units --type=service,mount,target --state=active --no-legend --plain 2>/dev/null \
    | awk '{print $1}' | head -n 80 > "$T/units"
cat > "$T/feed.sh" <<FEED
C="$P/bin/plymouth"
n=0
while read -r u; do
    "\$C" update --status="\$u"; sleep 0.04; n=\$((n + 1))
    [ "$SCENE" = password ] && [ \$n = 14 ] && { "\$C" ask-for-password --prompt="Enter passphrase for 'coyote':" --command=true & sleep 1.5; break; }
    [ \$n = 20 ] && [ "$SCENE" = boot ] && "\$C" update-root-fs --new-root-dir=/sysroot
done < "$T/units"
FEED
cat > "$T/inner.sh" <<INNER
#!/bin/bash
bwrap --unshare-user --uid 0 --gid 0 --dev-bind / / --dev /dev --proc /proc --tmpfs /run --bind /run/user /run/user \
  --bind "$T/themes" "$P/share/plymouth/themes" --unshare-net --unshare-pid --die-with-parent \
  bash -c '
    "$P/sbin/plymouthd" --no-daemon --mode=$MODE --no-boot-log --ignore-serial-consoles \
        --kernel-command-line="rhgb splash plymouth.debug=stream:$T/ply.log plymouth.ignore-udev plymouth.splash=schiefer" 2>"$T/ply.err" &
    D=\$!
    sleep 1.5
    "$P/bin/plymouth" show-splash; sleep 0.5
    . "$T/feed.sh"
    sleep 1; touch "$T/ready"; sleep 3
    "$P/bin/plymouth" quit; wait \$D
  ' &
B=\$!
for i in \$(seq 240); do [ -e "$T/ready" ] && break; sleep 0.25; done
spectacle -b -n -f -o "$OUT" >/dev/null 2>&1
wait \$B
INNER
chmod +x "$T/inner.sh"
timeout 120 dbus-run-session -- kwin_wayland --virtual --width "${BR_WIDTH:-1600}" --height "${BR_HEIGHT:-1000}" \
    --socket "plyshot-$$" --xwayland --no-lockscreen --exit-with-session "$T/inner.sh" >/dev/null 2>&1 || true
grep -E "script|error|Error" "$T/ply.log" 2>/dev/null | grep -v "^.*trying to load group" | tail -n 5 >&2 || true
[ -s "$OUT" ] && echo "$OUT"
