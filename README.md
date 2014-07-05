charmbian
=========

Debian install script for samsung arm chromebook

To run, just ./charmbian.sh

==The magic==
The magic part is just a honking debootstrap command to build a usable debian root from upstream sources to replace an existing arch root, using the arch kernel and modules to get you off of google's udders. It then does a few useful tweaks to make the system usable on first boot.
No really, for this to be useful in it's current state, you really do need two arch linux installs. The process looks like ChromeOS(int) -> arch (sd)-> arch (int) -> debian(int). Will try to cut out the middle men eventually.

==deps==
Runs on arch linux arm only, currently. 
Needs debootstrap 0.60 from debian testing repo installed
Designed to be run from an arch storage device against another arch storage device (Ie, from a bootable sd card arch install to the internal mmc overwriting another arch install)

==Danger will robinson!==
This will clobber /dev/mmc0p3 by default. Tell your data you love it, before it's too late. 
