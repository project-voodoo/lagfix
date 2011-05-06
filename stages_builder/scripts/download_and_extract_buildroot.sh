#!/bin/sh
FILENAME="buildroot-2011.02.tar.bz2"

if ! test -f $FILENAME ; then
	wget http://buildroot.uclibc.org/downloads/$FILENAME
fi
tar jxvf $FILENAME
