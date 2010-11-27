#!/bin/bash

cd zip30
ln -s ../../addons/Makefile-voodoo unix/
make -f unix/Makefile-voodoo clean
make -f unix/Makefile-voodoo -j8 generic

echo
ls -lh zip
echo -e "\nStriping the binary with sstrip"
../../stages_builder/buildroot-2010.08/output/staging/usr/arm-unknown-linux-uclibcgnueabi/bin/sstrip zip
echo
ls -lh zip

