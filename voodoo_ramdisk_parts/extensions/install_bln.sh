# Voodoo lagfix extension

name='BackLightNotification improved liblights'
source='/voodoo/extensions/bln/lights.PACKAGENAME.so'
dest='/system/lib/hw/lights.s5pc110.so'
backup='/system/lib/hw/lights.s5pc110.so-backup-'`date '+%Y-%m-%d_%H-%M-%S'`

extension_install_bln()
{
	# be nice, make a backup please
	mv $dest $backup
	cp $source $dest
	# make sure it's owned by root
	chown 0.0 $dest
	# set default permissions
	chmod 644 $dest
	log "$name now installed"
}

# see if our liblights is not installed
if ! cmp $source $dest; then
	# we need our liblights
	extension_install_bln
else
	# ours is the same don't touch it
	log "$name already installed"
fi	

