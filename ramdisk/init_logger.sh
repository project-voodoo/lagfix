#!/bin/sh
#
# Voodoo lagfix init script log wrapper
#

exec /init.sh >> /init.log 2>&1
