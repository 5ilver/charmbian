#!/bin/bash
# Charmbian
#
# Chrome device ARM Debian installer 
#
# Using arch kernel and modules is a massive hack and totally not needed, but I feel
# better about using a crappy repacked arch kernel than directly using the chromeos one.
#
# 2014 - This is hackerware. Do what you like with it as long as you learn something.

set -e
setterm -blank 0

which cgpt || exit
which parted || exit
which mkfs.vfat || exit
which mkfs.ext2 || exit
which mkfs.ext4 || exit
which wget || exit 
which debootstrap || exit 
which wpa_passphrase || exit 
which expr || exit 
which ping || exit 
which bunzip2 || exit 

echo "Checking for net..."
ping debian.org -c 1 || exit 1

echo "Enter device name (eg, /dev/sdb or /dev/mmcblk0)"
echo "Note: This will destroy all data. Avoid mixing with alcohol."
read devname
if [ ! -e "$devname" ] ; then
echo "Sorry, $devname doesn't exist"
exit
fi
#if it's an mmc device we need a p
echo "$devname" | egrep ^/dev/mmc && needp="p"
mount | grep $devname && umount "$devname"*

echo "Partitioning..."
parted -s $devname mklabel gpt
cgpt create -z $devname
cgpt create $devname

#Sizes are in blocks, one MB is 2048 blocks
#Root will take whatever is left over
ubootsize="4096"
scriptsize="32768"
bootsize="1048576"

ubootstart="8192"
bootstart="$(expr $ubootstart + $ubootsize)"
scriptstart="$(expr $bootstart + $bootsize)"
#Calculate the hole between Sec GPT table start and Script partition end to find the new Root size
gptsectable="$(cgpt show $devname | grep 'Sec GPT table' | awk '{print $1}')"
rootstart="$(expr $scriptstart + $scriptsize)"
rootsize="$(expr $gptsectable - $rootstart)"
cgpt add -i 1 -t kernel -b $ubootstart -s $ubootsize -l U-Boot -S 1 -T 5 -P 10 $devname
cgpt add -i 2 -t data -b $bootstart -s $bootsize -l Boot $devname
cgpt add -i 12 -t data -b $scriptstart -s $scriptsize -l Script $devname
cgpt add -i 3 -t data -b $rootstart -s $rootsize -l Root $devname
echo "/ is $(expr $rootsize / 2048)MB"
partprobe $devname

ubootpart="$devname""$needp""1"
bootpart="$devname""$needp""2"
rootpart="$devname""$needp""3"
scriptpart="$devname""$needp""12"

if [ -e /tmp/arch/ArchLinuxARM-chromebook-latest.tar.gz ]; then
echo "Looks like we have the arch tarball already"
else
mkdir /tmp/arch
mkdir /tmp/arch/root
echo "Downloading arch base image (to yoink kernel and modules)..."
wget -O - http://archlinuxarm.org/os/ArchLinuxARM-chromebook-latest.tar.gz > /tmp/arch/ArchLinuxARM-chromebook-latest.tar.gz.tmp
mv /tmp/arch/ArchLinuxARM-chromebook-latest.tar.gz.tmp /tmp/arch/ArchLinuxARM-chromebook-latest.tar.gz
fi

echo "Extracting arch base image in /tmp/arch..."
tar -xf /tmp/arch/ArchLinuxARM-chromebook-latest.tar.gz -C /tmp/arch/root

mkfs.ext2 -F "$bootpart"
mount -v "$bootpart" /mnt
cp -v /tmp/arch/root/boot/vmlinux.uimg /mnt/
umount /mnt

mkfs.vfat "$scriptpart"
mount "$scriptpart" /mnt
mkdir /mnt/u-boot
cp -v /tmp/arch/root/boot/boot.scr.uimg /mnt/u-boot/
umount /mnt

echo "Downloading nv-uboot bootloader..."
wget -O - http://commondatastorage.googleapis.com/chromeos-localmirror/distfiles/nv_uboot-snow.kpart.bz2 | bunzip2 > /tmp/nv_uboot-snow.kpart
echo "Writing nv-uboot to uboot partition..."
dd if=/tmp/nv_uboot-snow.kpart of="$ubootpart"

mkfs.ext4 -F "$rootpart"
echo "Starting debootstrap on $rootpart..."
mount $rootpart /mnt
debootstrap --no-check-gpg --components=main,non-free,contrib --arch=armhf --foreign --include=xdm,x11-xserver-utils,xserver-common,xserver-xorg,xserver-xorg-core,xserver-xorg-input-all,xserver-xorg-video-fbdev,links,gpicview,pcmanfm,iceweasel,xterm,fluxbox,xdm,xinit,usbutils,kmod,libkmod2,wget,curl,wireless-tools,wpasupplicant,x11-utils,vim,pm-utils jessie /mnt

echo "Package setup in the chroot..."
chroot /mnt /bin/sh -c "PATH=/bin:/sbin:/usr/sbin:/usr/local/sbin:$PATH /debootstrap/debootstrap --second-stage"

echo "Copying over arch kernel modules..."
cp -R /tmp/arch/root/lib/modules /mnt/lib/
echo "Copying over arch firmware..."
cp -R /tmp/arch/root/lib/firmware /mnt/lib/

echo "Extracting arch modules for debian..."
for compressedmodule in $(find /mnt/lib/modules | egrep ^*.ko.gz); do gunzip -v $compressedmodule; done

echo "depmod in the chroot..."
chroot /mnt /sbin/depmod

echo "Putting a basic sources.list in place..."
echo "deb http://http.us.debian.org/debian/ testing main contrib non-free" > /mnt/etc/apt/sources.list

echo "Putting a basic fstab in place..."
echo "$rootpart	/	ext4	noatime	0	0" > /mnt/etc/fstab
echo "$bootpart	/boot	ext2	noatime	0	0" >> /mnt/etc/fstab

echo "Setting up /etc/network/intrfaces.d file for mlan0..."
echo -e "allow-hotplug mlan0
auto mlan0
iface mlan0 inet dhcp
wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
wpa-driver wext" > /mnt/etc/network/interfaces.d/mlan0

echo "Putting a nice trackpad config in place..."
echo -e 'Section "InputClass"
Identifier "touchpad catchall"
Driver "synaptics"
MatchIsTouchpad "on"
MatchDevicePath "/dev/input/event*"
Option "FingerLow" "5"
Option "FingerHigh" "5"
Option "VertEdgeScroll" "0"
Option "HorizEdgeScroll" "0"
Option "VertTwoFingerScroll" "1"
Option "HorizTwoFingerScroll" "1"
Option "TapButton1" "1"
Option "TapButton2" "2"
Option "TapButton3" "3"
Option "ClickFinger1" "1"
Option "ClickFinger2" "3"
Option "ClickFinger3" "2"
Option "ClickPad" "1"
EndSection' > /mnt/usr/share/X11/xorg.conf.d/50-synaptics.conf  

#TODO Add some sleep hacks here
#Make sleep fire off when the lid closes
#Make the trackpad and keyboard unable to wake device (but only on lid close, reenable wakeup on open)

#TODO Add some sound hacks here
#Can we make an alsa device that controls Headphones and Speaker volume level?
#Can we add auto output switching?
#Can we limit to maybe 80% like chromeos does?
#Can we just copy the janky sound hacks chromeos already uses?

#TODO magic to make brightness and volume keyboard buttons work
#brightness control feels real smooth with an exponential curve, can that be done in a proper manner?

echo "Basic wpa_supplicant config setup..."
echo "ctrl_interface=/var/run/wpa_supplicant" > /mnt/etc/wpa_supplicant/wpa_supplicant.conf

echo "Cleaning up a few packages that break things..."
chroot /mnt /bin/bash -c "PATH=/usr/sbin:/usr/local/sbin:/sbin:/bin:/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/bin/core_perl /usr/bin/dpkg -r xserver-xorg-video-all xserver-xorg-video-modesetting"

echo "Lets set a root pw..."
chroot /mnt /bin/sh -c "passwd root"

echo "Want to set up a WPA1/2 wireless network in /etc/wpa_supplicant/wpa_supplicant.conf?"
echo "Enter an essid, or nothing to skip"
read essid
if [ ! $essid == "" ]; then 
	echo "Enter passphase (Will echo!)"
	read passphrase
	wpa_passphrase $essid $passphrase >> /mnt/etc/wpa_supplicant/wpa_supplicant.conf
fi

umount /mnt

echo "Ok, reboot and have fun!"
