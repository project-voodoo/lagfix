# Voodoo lagfix extension

# clean sdcard LOST.DIR that tend to grow despite the clean mount / umount
rm -rvf /sdcard/LOST.DIR/*

# these files are created on Froyo but as annoying as useless
rm -rvf /sdcard/DiskCacheIndex*.tmp

log "sdcard cleaned up"
