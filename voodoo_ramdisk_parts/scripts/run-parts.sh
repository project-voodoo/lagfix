#!/bin/sh
export PATH=/system/bin:/sbin:/system/xbin:/bin
log "Voodoo lagfix: running init.d scripts with run-parts"
logwrapper run-parts $*
