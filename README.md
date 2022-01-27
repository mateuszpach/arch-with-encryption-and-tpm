
# Arch Linux Full-Disk Encryption Using TPM Installation Guide For Thinkpad T440p
This guide provides instructions for an Arch Linux installation featuring full-disk encryption via LVM on LUKS and an encrypted boot partition (GRUB) for UEFI systems. It also prevents Evil Maid attacks making use of the UEFI Secure Boot (TPM) custom key enrollment and self-signed kernel and bootloader.
## Pre-installation
### Get Arch Linux ISO
Download the iso from an [official Archlinux page](https://archlinux.org/download/) and flash it on a media of your choice. Then boot from it.
## Quick solution
### Prepare another stick with scripts
Make sure it has FAT filesystem.
Copy directory scripts to it.
### Boot from arch iso
### Mounting usb stick with scripts
Run `fdisk` to check volumes names:
```
fdisk -l
```

Drive with scripts is likely to be the last one `sd*` volume.
Then run:

(DO NOT change the name of mounting directory)
```
mkdir scripts-stick
mount /dev/<name of your volume> scripts-stick
```
Contents of your usb stick should be in directory `scripts-stick` now.
### Connect to the internet
Plug in your Ethernet and go, or for wireless follow the commands.
List network interfaces to get available one e.g `wlan0`
```
iwctl device list
```
Scan for available networks and list them
```
iwctl station <interface> scan
iwctl station <interface> get-networks
```
Connect to the choosen one
```
iwctl station <interface> connect <ssid> --passphrase <passphrase>
```
### Running scripts
```
./scripts-stick/scripts/install1.sh
```
You will be asked to confirm disk erasure and prompted to enter new password to encrypted disk three times (it will later serve as boot password)
Repeat the steps as in "Mounting usb stick with scripts" section and run.
```
./scripts-stick/scripts/install2.sh
```
You will be asked to set root password and later to input encryption passphrase
Now reboot.
```
exit
reboot
```
#### After rebooting
You will be asked to input encryption passworda and then to login using root password, then repeat the steps from "Mounting usb stick with scripts"
#### Set up DHCP
```
./scripts-stick/scripts/network.sh
```
#### Connect to the internet as in "Connect to the internet"
#### Create keys, add signatures and create KeyTool on script stick
```
./scripts-stick/scripts/signing.sh
```
#### Then reboot to firmware
```
systemctl reboot --firmware
```
#### Unplug your arch-iso stick
##### Set boot to `UEFI only mode`
Go to `Startup` tab and set `UEFI/Legacy Boot` to `UEFI Only` and `CSM Support` to `No`.
##### Enable secure boot and reset to setup mode
Then go to `Security` tab and set `Secure Boot` to `Enabled` and `Reset to Setup Mode`.

Save and exit
##### Set new keys
Boot from your "script stick".
Go to Edit Keys menu and use Add New Key item to add keys in the following order: `db.auth` > `KEK.auth` > `PK.auth`
Exit and reboot.

##### Set UEFI supervisor (administrator) password
You must also set your UEFI firmware supervisor (administrator) password in the Security settings, so nobody can simply boot into UEFI setup utility and turn off Secure Boot.
You should never use the same UEFI firmware supervisor password as your encryption password, because on some old laptops, the supervisor password could be recovered as plaintext from the EEPROM chip.

##### Exit and save changes
Once you've loaded all three keys and set your supervisor password, hit F10 to exit and save your changes.

If everything was done properly, your boot loader should appear on reboot.

#### Check if Secure Boot was enabled
```
od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
```
The characters denoted by XXXX differ from machine to machine. To help with this, you can use tab completion or list the EFI variables.

If Secure Boot is enabled, this command returns 1 as the final integer in a list of five, for example:

```6  0  0  0  1```

If Secure Boot was enabled and your UEFI supervisor password set, you may now consider yourself protected against Evil Maid attacks.


## Detailed guide
### Connect to the internet
Plug in your Ethernet and go, or for wireless follow the commands.
List network interfaces to get available one e.g `wlan0`
```
iwctl device list
```
Scan for available networks and list them
```
iwctl station <interface> scan
iwctl station <interface> get-networks
```
Connect to the choosen one
```
iwctl station <interface> connect <ssid> --passphrase <passphrase>
```
### Set clock
```
timedatectl set-ntp true
```

### Preparing the disk
#### Create EFI System and Linux LUKS partitions
##### Create a 1MiB BIOS boot partition at start just in case it is ever needed in the future

Number | Start (sector) | End (sector) |    Size    | Code |        Name         |
-------|----------------|--------------|------------|------|---------------------|
1   |   2048         |   4095       | 1024.0 KiB | EF02 | BIOS boot partition |
2   |   4096         |   1130495    | 550.0 MiB  | EF00 | EFI System          |
3   |   1130496      |   976773134  | 465.2 GiB  | 8309 | Linux LUKS          |

```gdisk /dev/sda```
```
o
n
[Enter]
0
+1M
ef02
n
[Enter]
[Enter]
+550M
ef00
n
[Enter]
[Enter]
[Enter]
8309
w
```

#### Create the LUKS1 encrypted container on the Linux LUKS partition (GRUB does not support LUKS2 as of May 2019)
```cryptsetup luksFormat --type luks1 --use-random -S 1 -s 512 -h sha512 -i 5000 /dev/sda3```

#### Open the container (decrypt it and make available at /dev/mapper/cryptlvm)
```
cryptsetup open /dev/sda3 cryptlvm
```

### Preparing the logical volumes
#### Create physical volume on top of the opened LUKS container
```
pvcreate /dev/mapper/cryptlvm
```

#### Create the volume group and add physical volume to it
```
vgcreate vg /dev/mapper/cryptlvm
```

#### Create logical volumes on the volume group for swap, root, and home
```
lvcreate -L 8G vg -n swap
lvcreate -L 32G vg -n root
lvcreate -l 100%FREE vg -n home
```

The size of the swap and root partitions are a matter of personal preference.

#### Format filesystems on each logical volume
```
mkfs.ext4 /dev/vg/root
mkfs.ext4 /dev/vg/home
mkswap /dev/vg/swap
```

#### Mount filesystems
```
mount /dev/vg/root /mnt
mkdir /mnt/home
mount /dev/vg/home /mnt/home
swapon /dev/vg/swap
```

### Preparing the EFI partition
#### Create FAT32 filesystem on the EFI system partition
```
mkfs.fat -F32 /dev/sda2
```

#### Create mountpoint for EFI system partition at /efi for compatibility with and mount it
```
mkdir /mnt/efi
mount /dev/sda1 /mnt/efi
```

## Installation
### Install necessary packages
```
pacstrap /mnt base linux linux-firmware mkinitcpio lvm2 vi dhcpcd wpa_supplicant vim iwd ntfs-3g
```

## Configure the system
### Generate an fstab file
```
genfstab -U /mnt >> /mnt/etc/fstab
```

### Enter new system chroot
```
arch-chroot /mnt
```

#### At this point you should have the following partitions and logical volumes:
```lsblk```

NAME           | MAJ:MIN | RM  |  SIZE  | RO  | TYPE  | MOUNTPOINT |
---------------|---------|-----|--------|-----|-------|------------|
sda            |  259:0  |  0  | 465.8G |  0  | disk  |            |
├─sda1         |  259:4  |  0  |     1M |  0  | part  |            |
├─sda2         |  259:5  |  0  |   550M |  0  | part  | /efi       |
├─sda3         |  259:6  |  0  | 465.2G |  0  | part  |            |
..└─cryptlvm   |  254:0  |  0  | 465.2G |  0  | crypt |            |
....├─vg-swap  |  254:1  |  0  |     8G |  0  | lvm   | [SWAP]     |
....├─vg-root  |  254:2  |  0  |    32G |  0  | lvm   | /          |
....└─vg-home  |  254:3  |  0  | 425.2G |  0  | lvm   | /home      |

### Time zone
#### Set the time zone
Replace `Europe/Warsaw` with your respective timezone found in `/usr/share/zoneinfo`
```
ln -sf /usr/share/zoneinfo/Europe/Warsaw /etc/localtime
```

#### Run `hwclock` to generate ```/etc/adjtime```
Assumes hardware clock is set to UTC
```
hwclock --systohc
```

### Localization
#### Uncomment ```en_US.UTF-8 UTF-8``` in ```/etc/locale.gen``` and generate locale
```
sed -i '/#en_US.UTF-8/s/^#//g' /etc/locale.gen
locale-gen
```

#### Create ```locale.conf``` and set the ```LANG``` variable
```
touch /etc/locale.conf
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
```

### Network configuration
#### Create the hostname file
```
touch /etc/hostname
echo "myhostname" >> /etc/hostname
```

This is a unique name for identifying your machine on a network.

#### Add matching entries to hosts
```
touch /etc/hosts
echo -e "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 myhostname.localdomain myhostname" >> /etc/hosts
```

### Initramfs
#### Add the ```keyboard```, ```encrypt```, and ```lvm2``` hooks to ```/etc/mkinitcpio.conf```
*Note:* ordering matters.
```
sed -i "s|^HOOKS=.*|HOOKS=(base udev autodetect keyboard modconf block encrypt lvm2 filesystems fsck)|g" /etc/mkinitcpio.conf
```

#### Recreate the initramfs image
```
mkinitcpio -p linux
```

### Root password
#### Set the root password
```
passwd
```

### Boot loader
#### Install GRUB
```
pacman -S grub
```

#### Configure GRUB to allow booting from /boot on a LUKS1 encrypted partition
```
echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub
```

#### Set kernel parameter to unlock the LVM physical volume at boot using ```encrypt``` hook
##### UUID is the partition containing the LUKS container
```
export BLKID=$(blkid | grep sda3 | cut -d '"' -f 2)
export GRUBCMD="\"cryptdevice=UUID=$BLKID:cryptlvm root=/dev/vg/root cryptkey=rootfs:/root/secrets/crypto_keyfile.bin random.trust_cpu=on\""
echo GRUB_CMDLINE_LINUX=${GRUBCMD} >> /etc/default/grub
```

#### Install GRUB to the mounted ESP for UEFI booting
```
pacman -S efibootmgr
grub-install --target=x86_64-efi --efi-directory=/efi --modules="tpm" --disable-shim-lock
```

#### Enable microcode updates
##### grub-mkconfig will automatically detect microcode updates and configure appropriately
```
pacman -S intel-ucode
```

Use intel-ucode for Intel CPUs and amd-ucode for AMD CPUs.

#### Generate GRUB's configuration file
```
grub-mkconfig -o /boot/grub/grub.cfg
```

### Embed a keyfile in initramfs

This is done to avoid having to enter the encryption passphrase twice (once for GRUB, once for initramfs.)

#### Create a keyfile and add it as LUKS key
```
mkdir /root/secrets && chmod 700 /root/secrets
head -c 64 /dev/urandom > /root/secrets/crypto_keyfile.bin && chmod 600 /root/secrets/crypto_keyfile.bin
cryptsetup -v luksAddKey -i 1 /dev/sda3 /root/secrets/crypto_keyfile.bin
```

#### Add the keyfile to the initramfs image
```
sed -i "s|^FILES=.*|FILES=(/root/secrets/crypto_keyfile.bin)|g" /etc/mkinitcpio.conf
```

#### Recreate the initramfs image
```
mkinitcpio -p linux
```

#### Regenerate GRUB's configuration file
```
grub-mkconfig -o /boot/grub/grub.cfg
```

#### Restrict ```/boot``` permissions
```
chmod 700 /boot
```

The installation is now complete. Exit the chroot and reboot.
```
exit
reboot
```

## Post-installation
### Set up network and dhcp
```
echo "[General]\nEnableNetworkConfiguration=true" >> /etc/iwd/main.conf
systemctl enable --now iwd
systemctl enable --now dhcpcd
dhcpcd wlan0
```
####Connect to the internet as in "Connect to the internet" in Quick Guide
Your system should now be fully installed, bootable, and fully encrypted.

It should only require your encryption passphrase once to unlock to the system.

### Hardening against Evil Maid attacks
With an encrypted boot partition, nobody can see or modify your kernel image or initramfs, but you would be still vulnerable to [Evil Maid](https://www.schneier.com/blog/archives/2009/10/evil_maid_attac.html) attacks.

One possible solution is to use UEFI Secure Boot. Get rid of preloaded Secure Boot keys (you really don't want to trust Microsoft and OEM), enroll [your own Secure Boot keys](https://wiki.archlinux.org/index.php/Secure_Boot#Using_your_own_keys) and sign the GRUB boot loader with your keys. Evil Maid would be unable to boot modified boot loader (not signed by your keys) and the attack is prevented.

#### Creating keys
The following steps should be performed as the `root` user, with accompanying files stored in the `/root` directory.

##### Install `efitools`
```
pacman -S efitools
```

##### Create a GUID for owner identification
```
uuidgen --random > GUID.txt
```

##### Platform key
CN is a Common Name, which can be written as anything.

```
openssl req -newkey rsa:4096 -nodes -keyout PK.key -new -x509 -sha256 -days 3650 -subj "/CN=my Platform Key/" -out PK.crt
openssl x509 -outform DER -in PK.crt -out PK.cer
cert-to-efi-sig-list -g "$(< GUID.txt)" PK.crt PK.esl
sign-efi-sig-list -g "$(< GUID.txt)" -k PK.key -c PK.crt PK PK.esl PK.auth
```

##### Sign an empty file to allow removing Platform Key when in "User Mode"
```
sign-efi-sig-list -g "$(< GUID.txt)" -c PK.crt -k PK.key PK /dev/null rm_PK.auth
```

##### Key Exchange Key
```
openssl req -newkey rsa:4096 -nodes -keyout KEK.key -new -x509 -sha256 -days 3650 -subj "/CN=my Key Exchange Key/" -out KEK.crt
openssl x509 -outform DER -in KEK.crt -out KEK.cer
cert-to-efi-sig-list -g "$(< GUID.txt)" KEK.crt KEK.esl
sign-efi-sig-list -g "$(< GUID.txt)" -k PK.key -c PK.crt KEK KEK.esl KEK.auth
```

##### Signature Database key
```
openssl req -newkey rsa:4096 -nodes -keyout db.key -new -x509 -sha256 -days 3650 -subj "/CN=my Signature Database key/" -out db.crt
openssl x509 -outform DER -in db.crt -out db.cer
cert-to-efi-sig-list -g "$(< GUID.txt)" db.crt db.esl
sign-efi-sig-list -g "$(< GUID.txt)" -k KEK.key -c KEK.crt db db.esl db.auth
```

#### Signing bootloader and kernel
When Secure Boot is active (i.e. in "User Mode") you will only be able to launch signed binaries, so you need to sign your kernel and boot loader.

Install `sbsigntools`
```
pacman -S sbsigntools
```
```
sbsign --key db.key --cert db.crt --output /boot/vmlinuz-linux /boot/vmlinuz-linux
sbsign --key db.key --cert db.crt --output /efi/EFI/arch/grubx64.efi /efi/EFI/arch/grubx64.efi
```

##### Automatically sign bootloader and kernel on install and updates
It is necessary to sign GRUB with your UEFI Secure Boot keys every time the system is updated via `pacman`. This can be accomplished with a [pacman hook](https://jlk.fjfi.cvut.cz/arch/manpages/man/alpm-hooks.5).

Create the hooks directory
```
mkdir -p /etc/pacman.d/hooks
```

Create hooks for both the `linux` and `grub` packages

```/etc/pacman.d/hooks/99-secureboot-linux.hook```
```
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux

[Action]
Description = Signing Kernel for SecureBoot
When = PostTransaction
Exec = /usr/bin/find /boot/ -maxdepth 1 -name 'vmlinuz-*' -exec /usr/bin/sh -c 'if ! /usr/bin/sbverify --list {} 2>/dev/null | /usr/bin/grep -q "signature certificates"; then /usr/bin/sbsign --key /root/db.key --cert /root/db.crt --output {} {}; fi' \ ;
Depends = sbsigntools
Depends = findutils
Depends = grep
```

```/etc/pacman.d/hooks/98-secureboot-grub.hook```
```
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = grub

[Action]
Description = Signing GRUB for SecureBoot
When = PostTransaction
Exec = /usr/bin/find /efi/ -name 'grubx64*' -exec /usr/bin/sh -c 'if ! /usr/bin/sbverify --list {} 2>/dev/null | /usr/bin/grep -q "signature certificates"; then /usr/bin/sbsign --key /root/db.key --cert /root/db.crt --output {} {}; fi' \ ;
Depends = sbsigntools
Depends = findutils
Depends = grep
```

#### Enroll keys in firmware
##### Boot into UEFI firmware setup utility (frequently but incorrectly referred to as "BIOS")
```
systemctl reboot --firmware
```

##### Set boot to `UEFI only mode`
This may be necessary for Secure Boot to function.
Go to `Startup` tab and set `UEFI/Legacy Boot` to `UEFI Only` and `CSM Support` to `No`.
##### Enable secure boot and reset to setup mode
Then go to `Security` tab and set `Secure Boot` to `Enabled` and `Reset to Setup Mode`.

<!-- ##### Set or append the new keys
The keys must be set in the following order:
```db => KEK => PK```
This is due to some systems exiting setup mode as soon as a `PK` is entered. -->

##### Configure KeyTool to launch
Note: I refer to KeyTool-signed.efi rather than KeyTool.efi because the former should run after you've locked your platform down, but the latter won't. Either binary will work before you register your keys.

Copy KeyTool-signed.efi to a FAT USB flash drive under the filename EFI/BOOT/bootx64.efi. You'll then be able to boot from the USB flash drive as you would from an OS installation medium.

Copy all `*.cer`, `*.esl`, `*.auth` to the USB with KeyTool system partition
```
cp /root/*.cer /root/*.esl /root/*.auth <usb>/
```

##### Set new keys
Launch KeyTool.
Go to Edit Keys menu and use Add New Key item to add keys in the following order: `db.auth` > `KEK.auth` > `PK.auth`
Exit and reboot.

##### Set UEFI supervisor (administrator) password
You must also set your UEFI firmware supervisor (administrator) password in the Security settings, so nobody can simply boot into UEFI setup utility and turn off Secure Boot.
You should never use the same UEFI firmware supervisor password as your encryption password, because on some old laptops, the supervisor password could be recovered as plaintext from the EEPROM chip.

##### Exit and save changes
Once you've loaded all three keys and set your supervisor password, hit F10 to exit and save your changes.

If everything was done properly, your boot loader should appear on reboot.

#### Check if Secure Boot was enabled
```
od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
```
The characters denoted by XXXX differ from machine to machine. To help with this, you can use tab completion or list the EFI variables.

If Secure Boot is enabled, this command returns 1 as the final integer in a list of five, for example:

```6  0  0  0  1```

If Secure Boot was enabled and your UEFI supervisor password set, you may now consider yourself protected against Evil Maid attacks.

### References
- https://gist.github.com/huntrar/e42aee630bee3295b2c671d098c81268
- https://forum.manjaro.org/t/grub-fails-to-load-with-shim-and-secure-boot-enabled/62522
- https://linuxconfig.org/how-to-manage-wireless-connections-using-iwd-on-linux
- https://morfikov.github.io/post/jak-dodac-wlasne-klucze-dla-secure-boot-do-firmware-efi-uefi-pod-linux/
- https://www.rodsbooks.com/efi-bootloaders/controlling-sb.html
- https://giters.com/Foxboron/sbctl/issues/91
- https://wiki.ubuntu.com/UEFI/SecureBoot
- https://wiki.ubuntu.com/UEFI/SecureBoot/Testing
- https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Remove_PreLoader