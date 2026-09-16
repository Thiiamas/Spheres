#!/usr/bin/env bash
# Resolve the Godot binary for this project and forward every argument to it.
#
# The winget package folder embeds the version in the filename
# (Godot_v4.7.2-stable_win64_console.exe), so hard-coding a path breaks on the
# next `winget upgrade`. This picks the highest version present instead, and
# always the *_console* build — the plain .exe detaches from the terminal and
# swallows stdout, which is exactly what headless tests need to print.
#
# Override with GODOT_BIN=/path/to/godot_console.exe if you need a specific one.
set -euo pipefail

if [[ -n "${GODOT_BIN:-}" ]]; then
	exec "$GODOT_BIN" "$@"
fi

pkg_dir="${LOCALAPPDATA:-$HOME/AppData/Local}/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"

godot_bin="$(ls "$pkg_dir"/Godot_v*_console.exe 2>/dev/null | sort -V | tail -1 || true)"

if [[ -z "$godot_bin" ]]; then
	echo "tools/godot.sh: no Godot console binary found in $pkg_dir" >&2
	echo "  install it with:  winget install GodotEngine.GodotEngine" >&2
	echo "  or set GODOT_BIN to an explicit path." >&2
	exit 127
fi

exec "$godot_bin" "$@"
