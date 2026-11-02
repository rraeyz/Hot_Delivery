#!/usr/bin/env bash
# Renders Steam store art into marketing/steam/ (needs xvfb-run + godot).
# Capsules use the bright OpenGL renderer; screenshots use Vulkan (what players see).
# Usage: tools/store_art.sh ["TITLE"]
set -u
cd "$(dirname "$0")/.."
T=${1:-TIP OVER}
O=marketing/steam
mkdir -p "$O"
cap() {   # name WxH driver [extra args...]
	local n=$1 r=$2 d=$3; shift 3
	timeout 900 xvfb-run -a -s "-screen 0 3840x2160x24" godot --path . --rendering-driver "$d" --resolution "$r" -- \
		--autotest --capsule --out="$O" --name="$n" "$@" 2>&1 | grep -E "SCRIPT ERROR"
	echo "$n: $(file -b "$O/$n.png" 2>/dev/null | cut -d, -f2)"
}
cap header_capsule 920x430 opengl3 --title="$T"
cap small_capsule 462x174 opengl3 --title="$T" --title_size=150
cap main_capsule 1232x706 opengl3 --title="$T"
cap vertical_capsule 748x896 opengl3 --title="$T" --title_size=110 --title_pos=top --offset=0 --dist=7
cap library_capsule 600x900 opengl3 --title="$T" --title_size=100 --title_pos=top --offset=0 --dist=7.5
cap library_hero 3840x1240 opengl3
[ "${SHOTS:-1}" = 0 ] && exit 0   # SHOTS=0: capsules only
i=1
for a in "bazaar noon 3" "beach sunset 8" "downtown night 5" "bazaar morning 12" "beach noon 21"; do
	set -- $a
	cap "screenshot_$i" 1920x1080 vulkan --hud --theme="$1" --tod="$2" --seed="$3" --unlocks=7 --quality=2
	i=$((i + 1))
done
