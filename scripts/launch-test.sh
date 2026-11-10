#!/usr/bin/env bash
# Launch-test built apps inside the Iliada dev VM (run on the build server).
#
#   scripts/launch-test.sh <bundles-dir> <results-dir> [App.app ...]
#
# For each bundle: copy it into the VM's /Applications, start it in the live
# desktop session through iliada-run (as a click would), wait, record whether
# it is still running, its first errors, and a VNC screenshot, then stop it.
# Requires the dev VM (SSH on 127.0.0.1:2222, VNC :0) and sshpass/vncdo.
set -uo pipefail
BUNDLES="${1:?bundles dir}"; RESULTS="${2:?results dir}"; shift 2
WAIT="${WAIT:-20}"
SP=$(ls -d /nix/store/*-sshpass-*/bin/sshpass | head -1)
VNC=$(ls -d /nix/store/*-vncdotool-*/bin/vncdo | head -1)
VM() { "$SP" -p iliada ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -p 2222 iliada@127.0.0.1 "$@"; }
mkdir -p "$RESULTS"
if [ $# -gt 0 ]; then apps=("$@"); else mapfile -t apps < <(cd "$BUNDLES" && ls -d *.app); fi
printf '%-24s %-8s %s\n' APP RESULT NOTE > "$RESULTS/summary.txt"
for app in "${apps[@]}"; do
  name="${app%.app}"; safe="${name// /_}"
  echo "== $app"
  VM "rm -rf '/Applications/$app'"
  tar -C "$BUNDLES" -cf - "$app" | VM "tar -C /Applications -xf -"
  VM "bash -s" <<SH
export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1
ILIADA_ASSUME=allow setsid timeout $((WAIT + 10)) ${IR:-iliada-run} '/Applications/$app' > /tmp/launch-$safe.log 2>&1 < /dev/null &
SH
  sleep "$WAIT"
  # The app's own program (not the timeout/iliada-run/bwrap wrappers).
  entry=$(VM "sed -n 's/^entry = \"\\(.*\\)\"/\\1/p' '/Applications/$app/Contents/Info.toml'")
  prog=$(basename "$entry")
  alive=$(VM "ps -eo args | grep -v -e timeout -e iliada-run -e bwrap -e grep | grep -q -- '$prog' && echo yes || echo no")
  # Wake the display first (an idle session may have blanked it).
  "$VNC" -s 127.0.0.1::5900 -p iliada move 800 500 pause 1 move 810 505 pause 1 capture "$RESULTS/$safe.png" 2>/dev/null
  VM "grep -viE 'mesa|egl|zink|dri2|currency|session bus|machine-id|fontconfig warning' /tmp/launch-$safe.log | head -15" > "$RESULTS/$safe.log"
  VM "pkill -f '/Applications/$app'; true"
  sleep 3
  note=$(head -c 120 "$RESULTS/$safe.log" | tr '\n' ' ')
  printf '%-24s %-8s %s\n' "$name" "$([ "$alive" = yes ] && echo running || echo EXITED)" "$note" >> "$RESULTS/summary.txt"
done
cat "$RESULTS/summary.txt"
