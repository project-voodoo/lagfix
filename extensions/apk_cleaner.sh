# Voodoo lagfix extension

zip='/voodoo/extensions/apk_cleaner/zip'

# clean apk's inside!
apk='/system/app/TouchWiz30Launcher.apk'
if test -f $apk; then
	if test `du -s $apk | cut -d/ -f1` -gt 1500 ; then
		$zip -d $apk res/*1024x600*
		log "TouchWiz 3.0 Launcher cleaned up: apk now optimized"
	else
		log "TouchWiz 3.0 Launcher already optimized"
	fi
fi
