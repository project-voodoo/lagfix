#!/bin/sh
#
cd buildroot-2010.08/

cp output/toolchain/uClibc-0.9.31/.config ../configs/uClibc.config
cp output/build/busybox-1.17.1/.config ../configs/busybox.config
cp .config ../configs/buildroot.config

