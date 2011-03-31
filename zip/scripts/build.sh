#!/bin/bash

cd zip30
ln -s ../../addons/Makefile-voodoo unix/
make -f unix/Makefile-voodoo clean
make -f unix/Makefile-voodoo -j8 generic

echo
ls -lh zip
echo -e "\nStriping the binary with sstrip"
../../../arm-eabi/bin/arm-none-eabi-strip -I binary zip
echo
ls -lh zip

