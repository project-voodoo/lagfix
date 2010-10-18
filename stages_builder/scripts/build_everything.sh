#!/bin/sh

scripts/build_buildroot.sh
scripts/build_stage1.sh
scripts/build_stage2_image.sh
scripts/build_stage3-sound_image.sh
