#charmbian

Debian install script for samsung arm chromebook

To run, just ./charmbian.sh

##The magic
The magic part is just a honking debootstrap command to build a usable debian root from upstream sources using the arch kernel and modules to get you off of google's udders. It then does a few useful tweaks to make the system usable on first boot.

##deps
Needs debootstrap 0.60 from debian testing repo installed. Also needs cgpt and a bunch of other junk. Check the head of the script. Obviously you need to already be in dev mode with usb boot enabled.

##But what does it dooooooo?
* Partitions your device
* Grabs arch kernel and modules
* Grabs nv-uboot
* Debootstraps a debian system
* Puts a nice trackpad config in place
* Disables DPMS in xorg
* Sleep hacks in ACPI to disable KB/mouse wake when lid closed
* Sets up a WPA wifi connection 
* Boots to a minimal fluxbox graphical env
