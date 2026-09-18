#!/usr/bin/env bash
# Run every headless regression scene in tests/ and report a pass/fail summary.
#
#   tools/run_tests.sh                       # all tests
#   tools/run_tests.sh rune_chain progression  # only matching names
#
# Each test scene self-quits with exit 0 (PASS) / 1 (FAIL); WATCHDOG_FRAMES is
# only a safety net for a test that hangs instead of deciding.
set -uo pipefail

cd "$(dirname "$0")/.."
GODOT="./tools/godot.sh"
WATCHDOG_FRAMES="${WATCHDOG_FRAMES:-1200}"

# The shader scenes are visual lab scenes, not assertions — they never quit.
SKIP="shader_gallery shader_lab shader_showcase"

scenes=()
for tscn in tests/*.tscn; do
	name="$(basename "$tscn" .tscn)"
	[[ " $SKIP " == *" $name "* ]] && continue
	if (( $# > 0 )); then
		match=0
		for want in "$@"; do [[ "$name" == *"$want"* ]] && match=1; done
		(( match )) || continue
	fi
	scenes+=("$name")
done

if (( ${#scenes[@]} == 0 )); then
	echo "no matching test scenes" >&2
	exit 2
fi

echo "Godot $("$GODOT" --version)"
echo

failed=()
for name in "${scenes[@]}"; do
	printf '%-28s' "$name"
	# --quit-after counts main-loop ITERATIONS, not physics ticks, and headless
	# spins the loop about 2.4x faster than it steps physics. A test that has to
	# simulate real seconds of movement needs a much larger backstop than the
	# default. This matters more than it looks: the flag quits with exit code 0,
	# so a test killed by it is reported as a PASS. micro_terrain_test was doing
	# exactly that before this override, and now also enforces its own deadline
	# below the value here so it always concludes itself.
	watchdog="$WATCHDOG_FRAMES"
	case "$name" in
		micro_terrain_test) watchdog=8000 ;;
		macro_capture_test) watchdog=2400 ;;
	esac
	out="$("$GODOT" --headless --path . "res://tests/$name.tscn" \
		--quit-after "$watchdog" 2>&1)"
	code=$?
	if (( code == 0 )); then
		echo "PASS"
	else
		echo "FAIL (exit $code)"
		failed+=("$name")
		echo "$out" | tail -20 | sed 's/^/    /'
	fi
done

echo
if (( ${#failed[@]} == 0 )); then
	echo "All ${#scenes[@]} tests passed."
else
	echo "${#failed[@]}/${#scenes[@]} failed: ${failed[*]}"
	exit 1
fi
