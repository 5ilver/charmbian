#charmbian

Debian Jessie install script for samsung arm chromebook. Designed to be run ON the target device from something other than chromeos (chrubuntu or arch). Required arch packages can be installed with 'pacman -Syu git cgpt parted dosfstools wget binutils', debian/ubuntu package names are probably the same.

To run, just './charmbian.sh', then enter the target device path (/dev/mmcblk0 for internal emmc, /dev/mmcblk1 for sdcard, /dev/sda or /dev/sdb for usb devices). If booting from an external card, you may need to use CTRL+u at the dev mode screen, and you cannot boot from the blue usb3 port.

##The magic
The magic part is just a honking debootstrap command to build a usable debian root from upstream sources using the arch kernel and modules to get you off of google's udders. It then does a few useful tweaks to make the system usable on first boot.

##deps
Needs cgpt and a bunch of other junk. Check the head of the script if you like. Obviously you need to already be in dev mode with usb boot enabled.

##But what does it dooooooo?
* Partitions your device
* Grabs arch kernel and modules
* Grabs nv-uboot
* Grabs debootstrap
* Debootstraps a debian system
* Puts a nice trackpad config in place
* Disables DPMS in xorg
* Sleep hacks in ACPI to disable KB/mouse wake when lid is closed
* Sets up a WPA wifi connection with wpa_passphrase(if desired)
* Boots to a minimal fluxbox graphical env
