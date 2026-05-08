#!/usr/bin/env bash
set -euo pipefail

docker run --rm -it \
    -v "$PWD:/work" -w /work \
    zmkfirmware/zmk-build-arm:stable \
    bash -lc '
    set -euo pipefail
    [ -d .west ] || west init -l config
    west update --fetch-opt=--filter=tree:0
    west zephyr-export

    west build -s zmk/app -d build/left  -b nice_nano_v2 -- -DZMK_CONFIG=/work/config -DSHIELD=hillside46_left
    west build -s zmk/app -d build/right -b nice_nano_v2 -- -DZMK_CONFIG=/work/config -DSHIELD=hillside46_right

    mkdir -p /work/firmware
    cp build/left/zephyr/zmk.uf2 /work/firmware/left.uf2
    cp build/right/zephyr/zmk.uf2 /work/firmware/right.uf2
  '
