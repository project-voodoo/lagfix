#!/bin/sh

my_pwd=`pwd`
DEST=$my_pwd"/output/stage2.cpio.lzma"

cd target

find \
        etc/mke2fs.conf \
        lib/ \
        usr/sbin/mkfs.* \
        usr/sbin/fsck.* \
        usr/sbin/mke2fs \
        usr/sbin/e2fsck \
        usr/sbin/blkid \
        usr/sbin/tune2fs \
        usr/lib/libext2fs.* \
        usr/lib/libblkid.* \
        usr/lib/libuuid.* \
        usr/lib/libss.so* \
        usr/lib/libe2p.* \
        usr/lib/libcom_err.* \
        | cpio -v -H newc -o | lzma -9  > $DEST

ls -lh $DEST
