#!/bin/sh

my_pwd=`pwd`
DEST=$my_pwd"/stages/stage2.tar.lzma"

cd target

find \
        etc/mke2fs.conf \
        lib/ \
        usr/sbin/mkfs.* \
        usr/sbin/fsck.* \
        usr/sbin/mke2fs \
        usr/sbin/e2fsck \
        usr/sbin/tune2fs \
        usr/sbin/e2label \
        usr/lib/libext2fs.* \
        usr/lib/libblkid.* \
        usr/lib/libuuid.* \
        usr/lib/libss.so* \
        usr/lib/libe2p.* \
        usr/lib/libcom_err.* \
        | xargs tar cv | lzma -9  > $DEST

ls -lh $DEST
