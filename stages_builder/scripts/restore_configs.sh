#!/bin/sh
#

set -x
cd buildroot-2011.02/ 2>/dev/null

cp -v ../configs/buildroot.config .config

make uclibc-menuconfig
cp -v ../configs/uClibc.config output/toolchain/uClibc-0.9.31/.config

make busybox-configure
cp ../configs/busybox.config output/build/busybox-1.17.*/.config
