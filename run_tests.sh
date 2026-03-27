#!/usr/bin/env bash
set -euo pipefail

# GUT 9.6.0 requires Godot 4.6+. To test older versions, pin an older GUT
# in the submodule (9.5.0 for 4.5, 9.3.0 for 4.2).
#
# Godot binary path — override with environment variable
GODOT="${GODOT:-${GODOT_4_6:-godot}}"

RENDERERS=("forward_plus" "mobile" "gl_compatibility")

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="$PROJECT_DIR/test_results"
mkdir -p "$RESULTS_DIR"

if ! command -v "$GODOT" &>/dev/null; then
    echo "ERROR: Godot binary not found: $GODOT"
    echo "Set GODOT=/path/to/godot or GODOT_4_6=/path/to/godot"
    exit 1
fi

# GUT expects itself at res://addons/gut/ — create symlink if missing
if [ ! -e "$PROJECT_DIR/addons/gut" ]; then
    ln -sf ../tests/gut/addons/gut "$PROJECT_DIR/addons/gut"
    echo "Created symlink: addons/gut -> tests/gut/addons/gut"
fi

godot_version=$("$GODOT" --version 2>/dev/null | head -1)
echo "Using Godot: $GODOT ($godot_version)"

pass=0
fail=0

# Import resources (required for GUT class_names)
echo "--- Importing resources ---"
"$GODOT" --path "$PROJECT_DIR" --headless --import --quit 2>&1 | tail -1

for renderer in "${RENDERERS[@]}"; do
    echo ""
    echo "=== $renderer ==="

    log_file="$RESULTS_DIR/${renderer}.log"

    set +e
    "$GODOT" \
        --path "$PROJECT_DIR" \
        --rendering-method "$renderer" \
        -s res://tests/gut/addons/gut/gut_cmdln.gd \
        -gdir=res://tests \
        -gexit \
        2>&1 | tee "$log_file"
    exit_code=${PIPESTATUS[0]}
    set -e

    if [ $exit_code -eq 0 ]; then
        echo "PASS: $renderer"
        pass=$((pass + 1))
    else
        echo "FAIL: $renderer (exit code $exit_code)"
        fail=$((fail + 1))
    fi
done

echo ""
echo "==============================="
echo "  RESULTS"
echo "  Passed:  $pass"
echo "  Failed:  $fail"
echo "==============================="

exit $((fail > 0 ? 1 : 0))
