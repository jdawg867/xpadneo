#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/hid-xpadneo/src"

DEFAULT_KERNELS=(
    6.8.0-138-generic
    5.15.0-203-generic
)

if (( $# > 0 )); then
    KERNELS=("$@")
else
    KERNELS=("${DEFAULT_KERNELS[@]}")
fi

REPORT_DIR="${XPADNEO_TEST_REPORT_DIR:-${TMPDIR:-/tmp}/xpadneo-kernel-compat}"

mkdir -p "$REPORT_DIR"
REPORT_DIR="$(cd "$REPORT_DIR" && pwd)"

VERSION="$(git -C "$ROOT" describe --tags --always --dirty)"
JOBS="${XPADNEO_TEST_JOBS:-8}"

echo "===== XPADNEO KERNEL COMPATIBILITY ====="
echo "Source: $ROOT"
echo "Version: $VERSION"
echo "Reports: $REPORT_DIR"

FAILURES=0
BUILD_DIR=""

cleanup() {
    if [[ -n "$BUILD_DIR" && -d "$BUILD_DIR" ]]; then
        rm -rf -- "$BUILD_DIR"
    fi
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

for KERNEL in "${KERNELS[@]}"; do
    if [[ ! "$KERNEL" =~ ^[A-Za-z0-9._+-]+$ ]]; then
        echo "FAIL: invalid kernel name: $KERNEL"
        FAILURES=$((FAILURES + 1))
        continue
    fi
    echo
    echo "===== KERNEL: $KERNEL ====="

    HEADERS="/lib/modules/$KERNEL/build"
    LOG="$REPORT_DIR/$KERNEL.log"

    if [[ ! -d "$HEADERS" ]]; then
        echo "FAIL: missing kernel headers"
        FAILURES=$((FAILURES + 1))
        continue
    fi

    BUILD_DIR="$(mktemp -d)"

    # Keep the source tree untouched by building from
    # a temporary copy of the driver sources.
    cp -a "$SOURCE/." "$BUILD_DIR/"

    if make -j"$JOBS" \
        -C "$HEADERS" \
        M="$BUILD_DIR" \
        VERSION="\"$VERSION\"" \
        modules >"$LOG" 2>&1
    then
        MODULE="$BUILD_DIR/hid-xpadneo.ko"

        if [[ ! -f "$MODULE" ]]; then
            echo "FAIL: module artifact missing"
            FAILURES=$((FAILURES + 1))

        else
            VERMAGIC="$(modinfo -F vermagic "$MODULE")"

            if [[ "$VERMAGIC" == "$KERNEL "* ]]; then
                echo "PASS: build and vermagic"
                echo "Vermagic: $VERMAGIC"
                echo "Build log: $LOG"
            else
                echo "FAIL: vermagic mismatch"
                echo "Actual: $VERMAGIC"
                FAILURES=$((FAILURES + 1))
            fi
        fi

    else
        echo "FAIL: compiler or linker error"
        FAILURES=$((FAILURES + 1))

        grep -nE \
            'error:|fatal error:|Error [0-9]' \
            "$LOG" | head -30 || true
    fi

    cleanup
    BUILD_DIR=""
done

echo
echo "===== TEST SUMMARY ====="

if (( FAILURES == 0 )); then
    echo "PASS: all kernel compatibility builds"
else
    echo "FAIL: $FAILURES compatibility test(s)"
    exit 1
fi
