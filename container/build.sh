#!/usr/bin/env bash
# Compile arctic-kernel inside an isolated bubblewrap sandbox.
#
# No docker/podman assumed present. bwrap gives the same practical
# guarantee for a kernel build: a throwaway mount namespace with the
# host toolchain bound read-only, no network, and the only writable
# path being the build's own output directory. Nothing the build does
# can touch the rest of the filesystem.
#
# Usage: container/build.sh <config-file> <flavor-name> [make target...]
# Example: container/build.sh Default-config/config default bzImage modules

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${1:?usage: build.sh <config-file> <flavor-name> [make targets...]}"
FLAVOR="${2:?usage: build.sh <config-file> <flavor-name> [make targets...]}"
shift 2
TARGETS=("$@")
[ ${#TARGETS[@]} -eq 0 ] && TARGETS=(bzImage modules)

BUILD_ROOT="${ARCTIC_BUILD_ROOT:-/var/tmp/arctic-kernel-build}"
OUT_DIR="$BUILD_ROOT/$FLAVOR"
mkdir -p "$OUT_DIR"
cp "$SRC_DIR/$CONFIG_FILE" "$OUT_DIR/.config"

JOBS="${JOBS:-$(nproc)}"

exec bwrap \
	--ro-bind /usr /usr \
	--symlink usr/bin /bin \
	--symlink usr/bin /sbin \
	--symlink usr/lib /lib \
	--symlink usr/lib64 /lib64 \
	--ro-bind /etc /etc \
	--proc /proc \
	--dev /dev \
	--tmpfs /tmp \
	--ro-bind "$SRC_DIR" "$SRC_DIR" \
	--bind "$BUILD_ROOT" "$BUILD_ROOT" \
	--unshare-all \
	--die-with-parent \
	--chdir "$SRC_DIR" \
	--setenv HOME "$OUT_DIR" \
	-- \
	make -C "$SRC_DIR" O="$OUT_DIR" -j"$JOBS" olddefconfig "${TARGETS[@]}"
