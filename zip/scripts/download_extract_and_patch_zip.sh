#!/bin/sh
FILENAME=zip30.tar.gz

if ! test -f $FILENAME ; then
	wget "http://downloads.sourceforge.net/project/infozip/Zip%203.x%20%28latest%29/3.0/zip30.tar.gz?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Finfozip%2Ffiles%2F&ts=1290826930&use_mirror=freefr" -O $FILENAME
fi
tar zxvf $FILENAME
patch -p0 < addons/optimize_for_size.patch
