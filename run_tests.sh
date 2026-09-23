#!/usr/bin/env bash
set -euo pipefail

# GUT 9.6.0 requires Godot 4.6+. To test the addon's 4.4 minimum, temporarily
# check out GUT v9.4.0 in the submodule (supports Godot 4.3 and up).
#
# Tests need a real renderer, not --headless. To run without windows on your
# screen, use a virtual display (renders on llvmpipe, fine for correctness):
#   xvfb-run -a -s '-screen 0 1280x720x24' ./run_tests.sh
# A visible window also works; a covered one gets throttled to 1 fps and can
# make timing-based tests flaky.
#
# Godot binary path — override with environment variable
GODOT="${GODOT:-${GODOT_4_6:-godot}}"

# GUT's own UI logs an engine error on a separate render thread. GUT 9.5+ fails
# tests on engine errors, so limit that run to GUT and push_error errors.
# Older GUT doesn't track errors and doesn't know the flag.
gut_version=$(sed -n 's/^version="\(.*\)"/\1/p' "$(dirname "$0")/tests/gut/addons/gut/plugin.cfg")
separate_thread_gut_flags=""
if [ "$(printf '%s\n' 9.5.0 "$gut_version" | sort -V | head -1)" = "9.5.0" ]; then
    separate_thread_gut_flags="-gfailure_error_types=gut,push_error"
fi

# Each entry: renderer plus extra flags
RUNS=(
    "forward_plus"
    "mobile"
    "gl_compatibility"
    "forward_plus --render-thread separate $separate_thread_gut_flags"
)

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

for run in "${RUNS[@]}"; do
    read -r renderer extra_flags <<< "$run"
    run_name="${renderer}${extra_flags:+_separate_thread}"
    echo ""
    echo "=== $run ==="

    log_file="$RESULTS_DIR/${run_name}.log"

    set +e
    # shellcheck disable=SC2086
    "$GODOT" \
        --path "$PROJECT_DIR" \
        --rendering-method "$renderer" \
        $extra_flags \
        -s res://tests/gut/addons/gut/gut_cmdln.gd \
        -gdir=res://tests \
        -gexit \
        2>&1 | tee "$log_file"
    exit_code=${PIPESTATUS[0]}
    set -e

    if [ $exit_code -eq 0 ]; then
        echo "PASS: $run"
        pass=$((pass + 1))
    else
        echo "FAIL: $run (exit code $exit_code)"
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
