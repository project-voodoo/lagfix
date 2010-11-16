#!/bin/sh

my_pwd=`pwd`
DEST=$my_pwd"/stages/stage1.tar"

cd target

tar cvf $DEST bin/

ls -lh $DEST
