#!/bin/sh
PATH=/system/bin:/system/xbin:/sbin:/bin
log "Voodoo lagfix: running init.d scripts with run-parts"
logwrapper run-parts $*
