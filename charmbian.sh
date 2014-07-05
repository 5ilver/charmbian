#!/bin/bash
set -e
setterm -blank 0

echo "Checking for net..."
ping debian.org -c 1 || exit 1
target="/dev/mmcblk0p3"
echo "Target is $target"
mount | grep $target && umount $target
echo "Starting wipe and debootstrap on $target..."
mkfs.ext4 $target 
mount $target /mnt
debootstrap --components=main,non-free,contrib --arch=armhf --foreign --include=xdm,x11-xserver-utils,xserver-common,xserver-xorg,xserver-xorg-core,xserver-xorg-input-all,xserver-xorg-video-fbdev,links,gpicview,pcmanfm,iceweasel,xterm,fluxbox,xdm,xinit,usbutils,kmod,libkmod2,wget,curl,wireless-tools,wpasupplicant,x11-utils,vim,pm-utils testing /mnt

echo "Copying over kernel modules from current dist..."
cp -R /lib/modules /mnt/lib/
echo "Copying over firmware from current dist..."
cp -R /lib/firmware /mnt/lib/

echo "Extracting arch modules for debian..."
for compressedmodule in $(find /mnt/lib/modules | egrep ^*.ko.gz); do gunzip -v $compressedmodule; done

echo "Package setup in the chroot..."
chroot /mnt /bin/sh -c "PATH=/bin:/sbin:/usr/sbin:/usr/local/sbin:$PATH /debootstrap/debootstrap --second-stage"

echo "depmod in the chroot..."
chroot /mnt /sbin/depmod

echo "Putting a basic sources.list in place..."
echo "deb http://http.us.debian.org/debian/ testing main contrib non-free" > /mnt/etc/apt/sources.list

echo "Putting a basic fstab in place..."
echo "$target	/	ext4	noatime	0	0" > /mnt/etc/fstab

echo "Setting up /etc/network/intrfaces.d file for mlan0..."
echo "allow-hotplug mlan0" > /mnt/etc/network/interfaces.d/mlan0
echo "auto mlan0" >> /mnt/etc/network/interfaces.d/mlan0
echo "iface mlan0 inet dhcp" >> /mnt/etc/network/interfaces.d/mlan0
echo "wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf" >> /mnt/etc/network/interfaces.d/mlan0
echo "wpa-driver wext" >> /mnt/etc/network/interfaces.d/mlan0

echo "Basic wpa_supplicant config setup..."
echo "ctrl_interface=/var/run/wpa_supplicant" > /mnt/etc/wpa_supplicant/wpa_supplicant.conf

echo "Cleaning up a few packages that break things..."
chroot /mnt /usr/bin/dpkg -l | grep xserver
chroot /mnt /bin/bash -c "PATH=/usr/sbin:/usr/local/sbin:/sbin:/bin:/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/bin/core_perl /usr/bin/dpkg -r xserver-xorg-video-all xserver-xorg-video-modesetting"

echo "Lets set a root pw..."
chroot /mnt /bin/sh -c "passwd root"

echo "Want to set up a WPA1/2 wireless network?"
echo "Enter an essid, or nothing to skip"
read essid
if [ ! $essid == "" ]; then 
	echo "Enter passphase (Will echo!)"
	read passphrase
	wpa_passphrase $essid $passphrase >> /mnt/etc/wpa_supplicant/wpa_supplicant.conf
fi

echo "Ok, reboot to $target and have fun!"
