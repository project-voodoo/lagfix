#!/bin/sh
#
# Voodoo lagfix init script log wrapper
#

exec /voodoo/init.sh >> /init.log 2>&1
