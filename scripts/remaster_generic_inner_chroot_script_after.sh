#!/bin/bash

# do not remove these
/usr/sbin/env-update
source /etc/profile

eselect opengl set xorg-x11 &> /dev/null

# automatically start xdm
rc-update del xdm default
rc-update del xdm boot
rc-update add xdm boot

# consolekit must be run at boot level
rc-update add consolekit boot

# if it exists
if [ -f "/etc/init.d/hald" ]; then
	rc-update del hald boot
	rc-update del hald
	rc-update add hald boot
fi

rc-update del music boot
rc-update add music default

rc-update del sabayon-mce default

rc-update add nfsmount default

# Always startup this
rc-update add virtualbox-guest-additions boot

remove_desktop_files() {
	rm /etc/skel/Desktop/WorldOfGooDemo-world-of-goo-demo.desktop
}

setup_cpufrequtils() {
	rc-update add cpufrequtils default
}

setup_sabayon_mce() {
	rc-update add sabayon-mce boot
	# not needed, done by app-misc/sabayon-mce pkg
	# Sabayon Media Center user setup
	# source /sbin/sabayon-functions.sh
	# sabayon_setup_live_user "sabayonmce"
}

nspluginwrapper_autoinstall() {
	if [ -x /usr/bin/nspluginwrapper ]; then
		echo "Auto installing 32bit ns plugins..."
		nspluginwrapper -a -i
		ls /usr/lib/nsbrowser/plugins

		# Remove wrappers if equivalent 64-bit plugins exist
		# TODO: May be better to patch nspluginwrapper so it doesn't create
		#       duplicate wrappers in the first place...
		local DIR64="/usr/lib/nsbrowser/plugins/"
		for f in "${DIR64}"/npwrapper.*.so; do
			local PLUGIN=${f##*/npwrapper.}
			if [[ -f ${DIR64}/${PLUGIN} ]]; then
				echo "  Removing duplicate wrapper for native 64-bit ${PLUGIN}"
				nspluginwrapper -r "${f}"
			fi
		done
	fi
}

switch_kernel() {
	local from_kernel="${1}"
	local to_kernel="${2}"

	kernel-switcher switch "${to_kernel}"
	if [ "${?}" != "0" ]; then
		return 1
	fi
	equo remove "${from_kernel}"
	if [ "${?}" != "0" ]; then
		return 1
	fi
	return 0
}

setup_displaymanager() {
	# determine what is the login manager
	if [ -n "$(equo match --installed gnome-base/gdm -qv)" ]; then
		sed -i 's/DISPLAYMANAGER=".*"/DISPLAYMANAGER="gdm"/g' /etc/conf.d/xdm
	elif [ -n "$(equo match --installed lxde-base/lxdm -qv)" ]; then
		sed -i 's/DISPLAYMANAGER=".*"/DISPLAYMANAGER="lxdm"/g' /etc/conf.d/xdm
	elif [ -n "$(equo match --installed kde-base/kdm -qv)" ]; then
		sed -i 's/DISPLAYMANAGER=".*"/DISPLAYMANAGER="kdm"/g' /etc/conf.d/xdm
	else
		sed -i 's/DISPLAYMANAGER=".*"/DISPLAYMANAGER="xdm"/g' /etc/conf.d/xdm
	fi
}

setup_networkmanager() {
	rc-update del NetworkManager default
	rc-update del NetworkManager
	rc-update add NetworkManager default
}

gforensic_remove_skel_stuff() {
	# remove desktop icons
	rm /etc/skel/Desktop/*
	# remove no longer needed folders/files
	rm -r /etc/skel/.fluxbox
	rm -r /etc/skel/.e
	rm -r /etc/skel/.mozilla
	rm -r /etc/skel/.emerald
	rm -r /etc/skel/.xchat2
	rm -r /etc/skel/.config/compiz
	rm -r /etc/skel/.config/lxpanel
	rm -r /etc/skel/.config/pcmanfm
	rm -r /etc/skel/.config/Thunar
	rm -r /etc/skel/.config/xfce4
	rm -r /etc/skel/.gconf/apps/compiz
	rm -r /etc/skel/.gconf/apps/gset-compiz
}

setup_oss_gfx_drivers() {
	# do not tweak eselect mesa, keep defaults

	# This file is polled by the txt.cfg
	# (isolinux config file) setup script
	touch /.enable_kms
}

has_proprietary_drivers() {
	local is_nvidia=$(equo match --installed x11-drivers/nvidia-drivers -qv)
	if [ -n "${is_nvidia}" ]; then
		return 0
	fi
	local is_ati=$(equo match --installed x11-drivers/ati-drivers -qv)
	if [ -n "${is_ati}" ]; then
		return 0
	fi
	return 1
}

setup_proprietary_gfx_drivers() {
	# Prepare NVIDIA legacy drivers infrastructure

	if [ ! -d "/install-data/drivers" ]; then
		mkdir -p /install-data/drivers
	fi
	myuname=$(uname -m)
	mydir="x86"
	if [ "$myuname" == "x86_64" ]; then
		mydir="amd64"
	fi
	kernel_tag="#$(equo match --installed -qv sys-kernel/linux-sabayon | sort | head -n 1 | cut -d"-" -f 4 | sed 's/ //g')-sabayon"

	rm -rf /var/lib/entropy/client/packages/packages*/${mydir}/*/x11-drivers*
	ACCEPT_LICENSE="NVIDIA" equo install --fetch --nodeps =x11-drivers/nvidia-drivers-173*$kernel_tag
	ACCEPT_LICENSE="NVIDIA" equo install --fetch --nodeps =x11-drivers/nvidia-drivers-96.43.20*$kernel_tag
	# not working with >=xorg-server-1.5
	# ACCEPT_LICENSE="NVIDIA" equo install --fetch --nodeps ~x11-drivers/nvidia-drivers-71.86.*$kernel_tag
	mv /var/lib/entropy/client/packages/packages-nonfree/${mydir}/*/x11-drivers\:nvidia-drivers*.tbz2 /install-data/drivers/

	# if we ship with ati-drivers, we have KMS disabled by default.
	# and better set driver arch to classic
	eselect mesa set r600 classic
}

if [ "$1" = "lxde" ]; then
	setup_networkmanager
	# Fix ~/.dmrc to have it load LXDE
	echo "[Desktop]" > /etc/skel/.dmrc
	echo "Session=LXDE" >> /etc/skel/.dmrc
	remove_desktop_files
	setup_displaymanager
	# properly tweak lxde autostart tweak, adding --desktop option
	sed -i 's/pcmanfm -d/pcmanfm -d --desktop/g' /etc/xdg/lxsession/LXDE/autostart
	setup_cpufrequtils
	has_proprietary_drivers && setup_proprietary_gfx_drivers || setup_oss_gfx_drivers
elif [ "$1" = "e17" ]; then
	setup_networkmanager
	# Fix ~/.dmrc to have it load E17
        echo "[Desktop]" > /etc/skel/.dmrc
        echo "Session=enlightenment" >> /etc/skel/.dmrc
        remove_desktop_files
	# E17 spin has chromium installed
	setup_displaymanager
	# Not using lxdm for now
	# TODO: improve the lines below
	# Make sure enlightenment is selected in lxdm
	# sed -i '/lxdm-greeter-gtk/ a\\nlast_session=enlightenment.desktop\nlast_lang=' /etc/lxdm/lxdm.conf
	# Fix ~/.gtkrc-2.0 for some nice icons in gtk
	echo 'gtk-icon-theme-name="Tango" gtk-theme-name="Xfce"' | tr " " "\n" > /etc/skel/.gtkrc-2.0
	setup_cpufrequtils
	has_proprietary_drivers && setup_proprietary_gfx_drivers || setup_oss_gfx_drivers
elif [ "$1" = "xfce" ]; then
	setup_networkmanager
	# Fix ~/.dmrc to have it load Xfce
	echo "[Desktop]" > /etc/skel/.dmrc
	echo "Session=xfce" >> /etc/skel/.dmrc
	remove_desktop_files
	setup_cpufrequtils
	setup_displaymanager
	has_proprietary_drivers && setup_proprietary_gfx_drivers || setup_oss_gfx_drivers
elif [ "$1" = "fluxbox" ]; then
	setup_networkmanager
	# Fix ~/.dmrc to have it load Fluxbox
	echo "[Desktop]" > /etc/skel/.dmrc
	echo "Session=fluxbox" >> /etc/skel/.dmrc
	remove_desktop_files
	setup_displaymanager
	setup_cpufrequtils
	has_proprietary_drivers && setup_proprietary_gfx_drivers || setup_oss_gfx_drivers
elif [ "$1" = "gnome" ]; then
	setup_networkmanager
	# Fix ~/.dmrc to have it load GNOME
	echo "[Desktop]" > /etc/skel/.dmrc
	echo "Session=gnome" >> /etc/skel/.dmrc
	rc-update del system-tools-backends boot
	rc-update add system-tools-backends default
	setup_displaymanager
	setup_sabayon_mce
	has_proprietary_drivers && setup_proprietary_gfx_drivers || setup_oss_gfx_drivers
elif [ "$1" = "gforensic" ]; then
	setup_networkmanager
	# Fix ~/.dmrc to have it load GNOME
	echo "[Desktop]" > /etc/skel/.dmrc
	echo "Session=gnome" >> /etc/skel/.dmrc
	rc-update del system-tools-backends boot
	rc-update add system-tools-backends default
	setup_displaymanager
	setup_sabayon_mce
	gforensic_remove_skel_stuff
	setup_cpufrequtils
	has_proprietary_drivers && setup_proprietary_gfx_drivers || setup_oss_gfx_drivers
elif [ "$1" = "kforensic" ]; then
	setup_networkmanager
	# Fix ~/.dmrc to have it load KDE
	echo "[Desktop]" > /etc/skel/.dmrc
	echo "Session=KDE-4" >> /etc/skel/.dmrc
	rc-update del system-tools-backends boot
	rc-update add system-tools-backends default
	setup_displaymanager
	setup_sabayon_mce
	gforensic_remove_skel_stuff
	setup_cpufrequtils
	has_proprietary_drivers && setup_proprietary_gfx_drivers || setup_oss_gfx_drivers
elif [ "$1" = "kde" ]; then
	setup_networkmanager
	# Fix ~/.dmrc to have it load KDE
	echo "[Desktop]" > /etc/skel/.dmrc
	echo "Session=KDE-4" >> /etc/skel/.dmrc
	setup_displaymanager
	setup_sabayon_mce
	setup_cpufrequtils
	has_proprietary_drivers && setup_proprietary_gfx_drivers || setup_oss_gfx_drivers
elif [ "$1" = "awesome" ]; then
	setup_networkmanager
	# Fix ~/.dmrc to have it load Awesome
	echo "[Desktop]" > /etc/skel/.dmrc
	echo "Session=awesome" >> /etc/skel/.dmrc
	switch_kernel "sys-kernel/linux-sabayon" "sys-kernel/linux-fusion"
	remove_desktop_files
	setup_displaymanager
	setup_cpufrequtils
	has_proprietary_drivers && setup_proprietary_gfx_drivers || setup_oss_gfx_drivers
fi

# Make sure that pango stuff is properly configured
# It happens with E17 lives, for sure there is something broken
# somewhere.
if [ -x "/usr/bin/pango-querymodules" ]; then
	if [ "$(uname -m)" = "x86_64" ]; then
		/usr/bin/pango-querymodules > "/etc/pango/x86_64-pc-linux-gnu/pango.modules"
	else
		/usr/bin/pango-querymodules > "/etc/pango/pango.modules"
	fi
fi

# Setup SAMBA config file
if [ -f /etc/samba/smb.conf.default ]; then
	cp -p /etc/samba/smb.conf.default /etc/samba/smb.conf
fi

# if Sabayon GNOME, drop qt-gui bins
gnome_panel=$(qlist -ICve gnome-base/gnome-panel)
if [ -n "${gnome_panel}" ]; then
        find /usr/share/applications -name "*qt-gui*.desktop" | xargs rm
fi
# we don't want this on our ISO
rm -f /usr/share/applications/sandbox.desktop

# beanshell app, not wanted in our start menu
rm -f /usr/share/applications/bsh-console-bsh.desktop

# drop gnome-system-log desktop file (broken)
rm -f /usr/share/applications/gnome-system-log.desktop

# Remove wicd from autostart
rm -f /usr/share/autostart/wicd-tray.desktop /etc/xdg/autostart/wicd-tray.desktop

# EXPERIMENTAL, clean icon cache files
for file in `find /usr/share/icons -name "icon-theme.cache"`; do
        rm $file
done

# Fixup nsplugins
# we have new Flash, don't need it anymore
# nspluginwrapper_autoinstall

# Update package list
equo query list installed -qv > /etc/sabayon-pkglist

# Setup basic GTK theme for root user
if [ ! -f "/root/.gtkrc-2.0" ]; then
	echo "include \"/usr/share/themes/Clearlooks/gtk-2.0/gtkrc\"" > /root/.gtkrc-2.0
fi

# Regenerate Fluxbox menu
if [ -x "/usr/bin/fluxbox-generate_menu" ]; then
	fluxbox-generate_menu -o /etc/skel/.fluxbox/menu
fi

layman -d sabayon
rm -rf /var/lib/layman/sabayon


echo -5 | equo conf update
mount -t proc proc /proc
/lib/rc/bin/rc-depend -u

echo "Vacuum cleaning client db"
rm /var/lib/entropy/client/database/*/sabayonlinux.org -rf
rm /var/lib/entropy/client/database/*/sabayon-weekly -rf
equo rescue vacuum

# restore original repositories.conf (all mirrors were filtered for speed)
cp /etc/entropy/repositories.conf.example /etc/entropy/repositories.conf || exit 1

# cleanup log dir
rm /var/lib/entropy/logs -rf

# Generate openrc cache
touch /lib/rc/init.d/softlevel
/etc/init.d/savecache start
/etc/init.d/savecache zap

ldconfig
ldconfig
umount /proc

emaint --fix world

rm -rf /var/lib/entropy/*cache*

# remove entropy pid file
rm -f /var/run/entropy/entropy.lock

exit 0
