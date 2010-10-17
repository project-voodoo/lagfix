#!/bin/sh
#
cd buildroot-2010.08/

make uclibc-menuconfig
cp -v ../configs/uClibc.config output/toolchain/uClibc-0.9.31/.config

make busybox-configure
cp -v ../configs/busybox.config output/build/busybox-1.17.1/.config

cp -v ../configs/buildroot.config .config

