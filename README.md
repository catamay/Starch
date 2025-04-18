# Starch

A minimal Arch Linux installation for running jujube on dedicated arcade
cabinets. Forked from [Starch](https://github.com/root670/Starch)

## Features

* Unattended installation. You only need to specify a device to install to
* Boots to StepMania running in its own X session without a desktop environment
* Downloads and compiles latest StepMania revision from GitHub
* Uses proprietary NVIDIA driver if an NVIDIA graphics card is installed

## System Requirements

* System capable of booting in UEFI mode
* Internet connection at time of installation

## Installation Instructions

1. Download latest Arch installation media from
   [here](https://www.archlinux.org/download/) and write it to a USB drive using
   Rufus or dd.

2. Boot from installation media using the UEFI boot partition. You may need to
   disable secure boot if it's currently enabled.

3. Ensure you have a working Internet connection once the terminal appears. For
   wired connections, a connection should be established automatically using
   DHCP. For wireless connections, `wifi-menu` can be used to connect to a
   network. The
   [ArchWiki](https://wiki.archlinux.org/index.php/Network_configuration)
   provides more detailed instructions if needed.

4. Download, extract, and run the install script to begin installation:

```
wget github.com/catamay/Starch/archive/master.zip
bsdtar -xf master.zip
cd Starch-master
bash install.sh
```

## Notes

* IO boards for pads and/or lights (PIUIO, P4IO, LitBoard, MiniMaid, etc.)
  aren't supported out-of-the-box. If you're able to get any IO boards working
  with Starch, please let me know and I'll look into adding support for it in
  the installation script.
* If using in an SD cabinet with a CRT monitor, you'll need to create a custom X
  config script similar to how ITG does.
* Terminal can be accessed by holding `Ctrl+Alt` and pressing `F2` through `F7`.
* To connect to the network using DHCP, run `systemctl start dhcpcd.service` to
  start the DHCP client service. `systemctl enable dhcpcd.service` will cause
  the service to start automatically on every boot.

## Disclaimer

**Use at your own risk!** This has been tested in VirtualBox and on my own
desktop, but **not in an actual cabinet**.
