#!/bin/sh

my_pwd=`pwd`
DEST=$my_pwd"/stages/stage3-sound.tar.lzma"

cd target

tar cv \
	usr/lib/libasound* \
	usr/share/alsa/alsa.conf \
	usr/bin/aplay \
	usr/bin/madplay \
	usr/lib/libmad* \
	usr/lib/libid3* \
	usr/lib/libz* \
	| lzma -9  > $DEST

ls -lh $DEST
