#!/bin/sh
#
cd buildroot-2010.08/

cp -v output/toolchain/uClibc-0.9.31/.config ../configs/uClibc.config
cp -v output/build/busybox-1.17.1/.config ../configs/busybox.config
cp -v .config ../configs/buildroot.config

