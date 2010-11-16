#!/bin/sh
PATH=/system/bin:/system/xbin:/sbin:/bin
run-parts $* || busybox run-parts $*
