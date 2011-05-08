#!/bin/sh

my_pwd=`pwd`
DEST=$my_pwd"/stages/stage1.tar"

cd target

cp -a sbin/* bin/
tar cvf $DEST bin/

ls -lh $DEST
