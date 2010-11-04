#!/bin/sh
cd buildroot*/output/build/busybox*/

find -name *.o.cmd | sed s/'\/\.\(.*\).o.cmd'/'\/'\\1.c/ | sed s/'^.\/'/''/
