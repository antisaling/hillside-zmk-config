#!/usr/bin/env bash
set -euo pipefail

docker run --rm \
    -v "$PWD:/work" -w /work \
    zmkfirmware/zmk-build-arm:stable \
    bash -lc '
    set -euo pipefail
    [ -d .west ] || west init -l config

    MANIFEST_FILE=config/west.yml
    MANIFEST_STAMP=.west/manifest.sha256
    CURRENT_MANIFEST_HASH="$(sha256sum "$MANIFEST_FILE" | awk "{print \$1}")"

    NEED_WEST_UPDATE=0
    [ -d zmk/.git ] || NEED_WEST_UPDATE=1
    [ -d zephyr/.git ] || NEED_WEST_UPDATE=1
    [ -f "$MANIFEST_STAMP" ] || NEED_WEST_UPDATE=1

    if [ "$NEED_WEST_UPDATE" -eq 0 ] && [ "$(cat "$MANIFEST_STAMP")" != "$CURRENT_MANIFEST_HASH" ]; then
      NEED_WEST_UPDATE=1
    fi

    if [ "${FORCE_WEST_UPDATE:-0}" = "1" ]; then
      NEED_WEST_UPDATE=1
    fi

    if [ "$NEED_WEST_UPDATE" -eq 1 ]; then
      echo "west update: syncing deps"
      west update --fetch-opt=--filter=tree:0
      printf "%s\n" "$CURRENT_MANIFEST_HASH" > "$MANIFEST_STAMP"
    else
      echo "west update: skipped (deps + manifest unchanged)"
    fi

    west zephyr-export

    USE_CCACHE=0
    if command -v ccache >/dev/null 2>&1; then
      USE_CCACHE=1
      export CCACHE_DIR=/work/.ccache
      export CCACHE_BASEDIR=/work
      export CCACHE_COMPILERCHECK=content
      mkdir -p "$CCACHE_DIR"
      ccache --max-size=2G >/dev/null 2>&1 || true
      echo "ccache: enabled at $CCACHE_DIR"
    else
      echo "ccache: not available in container image"
    fi

    build_target() {
      local build_dir="$1"
      local shield="$2"

      if [ -f "$build_dir/CMakeCache.txt" ]; then
        echo "west build: incremental $build_dir"
        west build -d "$build_dir"
        return
      fi

      local cmake_args=(-DZMK_CONFIG=/work/config -DSHIELD="$shield")
      if [ "$USE_CCACHE" -eq 1 ]; then
        cmake_args+=(-DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache)
      fi

      echo "west build: configure $build_dir ($shield)"
      west build -s zmk/app -d "$build_dir" -b nice_nano_v2 -- "${cmake_args[@]}"
    }

    build_target build/left hillside46_left
    build_target build/right hillside46_right

    mkdir -p /work/firmware
    cp build/left/zephyr/zmk.uf2 /work/firmware/left.uf2
    cp build/right/zephyr/zmk.uf2 /work/firmware/right.uf2
  '
