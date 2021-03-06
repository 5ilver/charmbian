#!/bin/bash
# Charmbian
#
# Chrome device ARM Debian installer 
#
#

# follow instructions at https://archlinuxarm.org/platforms/armv7/samsung/samsung-chromebook-2 or appropriate to make a usb stick that will boot arch, then copy this script to partition 2 and run it from the live usb stick on the target machine
# 2020 - This is hackerware. Do what you like with it as long as you learn something.

#wifi seems broken in a debian buster target right now. On the bright side, suspend/resume work!

setterm -blank 0

echo "Set up a WPA1/2 wireless network"
echo "Enter an essid, or nothing to skip"
read essid
if [ ! $essid == "" ]; then 
	echo "Enter passphase (Will echo!)"
	read passphrase
	wpa_passphrase $essid $passphrase >> /tmp/wpa_supplicant.conf
	wpa_supplicant -c /tmp/wpa_supplicant.conf -i mlan0 &
	sleep 5
	echo sharting dhcp
	dhcpcd
	sleep 5
fi

pacman-key --init
pacman-key --populate archlinuxarm


pacman --noconfirm -Sy cgpt parted wget binutils

which cgpt
which parted
which mkfs.ext4
which wget
which expr
which ping
which bunzip2
which chroot
which ar



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

#Sizes are in blocks, one MB is 2048 blocks
parted -s $devname mklabel gpt
cgpt create -z $devname
cgpt create $devname
kernelstart="8192"
kernelsize="32768"
rootstart="40960"
#Calculate the hole between Sec GPT table start and Kernel partition end to find the new Root size
gptsectable="$(cgpt show $devname | grep 'Sec GPT table' | awk '{print $1}')"
#Root will take whatever is left over
rootsize="$(expr $gptsectable - $rootstart)"
echo "/ is $(expr $rootsize / 2048)MB"
cgpt add -i 1 -t kernel -b $kernelstart -s $kernelsize -l Kernel -S 1 -T 5 -P 10 $devname
cgpt add -i 2 -t data -b $rootstart -s $rootsize -l Root $devname
partprobe $devname

kernelpart="$devname""$needp""1"
rootpart="$devname""$needp""2"

echo "Copying kernel..."
#cheating and assuming we are on /dev/sda
dd if=/dev/sda1 of=$kernelpart

echo "Downloading debootstrap..."
wget http://ftp.us.debian.org/debian/pool/main/d/debootstrap/debootstrap_1.0.123_all.deb
ar x debootstrap_1.0.123_all.deb
tar -xf data.tar.gz
echo "Starting debootstrap on $rootpart..."
mkfs.ext4 -F "$rootpart"
mount $rootpart /mnt

DEBOOTSTRAP_DIR=usr/share/debootstrap usr/sbin/debootstrap --no-check-gpg --components=main,non-free,contrib --arch=armhf --foreign --include=alsa-utils,acpid,xdm,x11-xserver-utils,xserver-common,xserver-xorg,xserver-xorg-core,xserver-xorg-input-all,xserver-xorg-video-fbdev,links,gpicview,pcmanfm,iceweasel,xterm,fluxbox,xdm,xinit,usbutils,kmod,libkmod2,wget,curl,wireless-tools,wpasupplicant,x11-utils,vim,pm-utils stable /mnt

echo "Package setup in the chroot..."
chroot /mnt /bin/sh -c "PATH=/bin:/sbin:/usr/sbin:/usr/local/sbin:$PATH /debootstrap/debootstrap --second-stage"

echo "Copying over arch kernel modules..."
cp -R /lib/modules /mnt/lib/
echo "Copying over arch firmware..."
cp -R /lib/firmware /mnt/lib/

echo "Extracting arch modules for debian..."
for compressedmodule in $(find /mnt/lib/modules | egrep ^*.ko.gz); do gunzip -v $compressedmodule; done

echo "depmod in the chroot..."
chroot /mnt /sbin/depmod

echo "Putting a basic sources.list in place..."
echo "deb http://http.us.debian.org/debian/ stable main contrib non-free" > /mnt/etc/apt/sources.list

echo "Putting a basic fstab in place..."
echo "/dev/disk/by-partlabel/Root	/	ext4	noatime	0	0" > /mnt/etc/fstab

echo "Setting up /etc/network/interfaces.d file for mlan0..."
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

echo -e 'Section "Monitor"
    Identifier "LVDS0"
    Option "DPMS" "false"
EndSection

Section "ServerLayout"
    Identifier "ServerLayout0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime" "0"
EndSection' > /mnt/usr/share/X11/xorg.conf.d/10-monitor.conf

#I don't actually know which of these works but I needed them on a snow...
echo -e '#!/bin/sh
echo "$(date) lid $3" >> /var/log/lid
case $3 in
  open)
    echo enabled > /sys/devices/s3c2440-i2c.0/i2c-0/0-0009/power/wakeup
    echo enabled > /sys/devices/s3c2440-i2c.1/i2c-1/1-0025/power/wakeup
    echo enabled > /sys/devices/s3c2440-i2c.1/i2c-1/1-0067/power/wakeup
    echo enabled > /sys/devices/s3c2440-i2c.1/i2c-1/1-004b/power/wakeup
    echo enabled > /sys/devices/s3c2440-i2c.4/i2c-4/4-001e/power/wakeup
    ;;
  close)
    echo disabled > /sys/devices/s3c2440-i2c.0/i2c-0/0-0009/power/wakeup
    echo disabled > /sys/devices/s3c2440-i2c.1/i2c-1/1-0025/power/wakeup
    echo disabled > /sys/devices/s3c2440-i2c.1/i2c-1/1-0067/power/wakeup
    echo disabled > /sys/devices/s3c2440-i2c.1/i2c-1/1-004b/power/wakeup
    echo disabled > /sys/devices/s3c2440-i2c.4/i2c-4/4-001e/power/wakeup
    pm-suspend
    ;;
esac' > /mnt/etc/acpi/lid.sh

echo -e '# /etc/acpi/events/lidbtn
# Called when the user closes or opens the lid

event=button/lid*
action=/etc/acpi/lid.sh %e' > /mnt/etc/acpi/events/lidbtn

chmod +x /mnt/etc/acpi/lid.sh
chmod +x /mnt/etc/acpi/events/lidbtn
 
#TODO Add some sound hacks here
#Can we make an alsa device that controls Headphones and Speaker volume level?
#Can we add auto output switching?
#Can we limit to maybe 80% like chromeos does?
#Can we just copy the janky sound hacks chromeos already uses?
echo 'amixer | grep "Speaker\|Headphone" | grep DAC1 | sed "s/Simple mixer control //" | sed "s/,0//" | while read mixcontrol; do amixer sset "$mixcontrol" on; done; exit 0;' > /mnt/etc/rc.local

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
echo "(you may need to run wpa_suppliciant -c /etc/wpa_supplicant/wpa_supplicant.conf and"
echo "dhclient to activate wifi on boot now due to changes in buster"
read essid
if [ ! $essid == "" ]; then 
	echo "Enter passphase (Will echo!)"
	read passphrase
	wpa_passphrase $essid $passphrase >> /mnt/etc/wpa_supplicant/wpa_supplicant.conf
fi

umount /mnt

echo "Ok, reboot and have fun!"
