#!/bin/sh

cd zip30
ln -s ../../addons/Makefile-voodoo unix/
make -f unix/Makefile-voodoo clean
make -f unix/Makefile-voodoo -j8 generic
