#!/bin/sh
#
# Voodoo lagfix init script log wrapper
#

exec /voodoo/scripts/init.sh >> /init.log 2>&1
