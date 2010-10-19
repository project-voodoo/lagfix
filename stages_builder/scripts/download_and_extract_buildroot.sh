#!/bin/sh
FILENAME="buildroot-2010.08.tar.bz2"

if ! test -f $FILENAME ; then
	wget http://buildroot.uclibc.org/downloads/$FILENAME
fi
tar jxvf buildroot-2010.08.tar.bz2
