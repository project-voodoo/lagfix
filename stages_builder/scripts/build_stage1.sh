#!/bin/sh

my_pwd=`pwd`
DEST=$my_pwd"/stages/stage1.tar"

cd target

find bin/ | xargs tar cvf $DEST

ls -lh $DEST
