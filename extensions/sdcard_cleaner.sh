# Voodoo lagfix extension

# clean sdcard LOST.DIR that tend to grow despite the clean mount / umount
rm -rf /sdcard/LOST.DIR

# these files are created on Froyo but as annoying as useless
rm -rf /sdcard/DiskCacheIndex*.tmp

log "sdcard cleaned up"
