#!/bin/sh

my_pwd=`pwd`
DEST=$my_pwd"/stages/stage1.cpio"

cd target

find bin/ | cpio -v -H newc -o > $DEST

ls -lh $DEST
