#!/bin/sh
#
cd buildroot-2011.02/ 2>/dev/null

if cp output/toolchain/uClibc-0.9.31/.config ../configs/uClibc.config && \
	cp output/build/busybox-1.17.*/.config ../configs/busybox.config && \
	cp .config ../configs/buildroot.config; then
		echo "Configs saved, no error :)"
else
	echo "Config saving error, please check the output"
fi
