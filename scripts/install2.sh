echo Setting the time zone
ln -sf /usr/share/zoneinfo/Europe/Warsaw /etc/localtime
echo Running hwclock to genereate /etc/adjtime, assuming that hardware clock is set to UTC
hwclock --systohc
echo Localization
sed -i '/#en_US.UTF-8/s/^#//g' /etc/locale.gen
locale-gen
echo Creating locale.conf and setting the LANG variable
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo Network configuration
echo Creating hostname file
echo "myhostname" >> /etc/hostname
echo Adding matching entries to the hosts
echo -e "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 myhostname.localdomain myhostname" >> /etc/hosts
echo the keyboard, encrypt and lvm2 hooks to /etc/mkinitcpio.conf
sed -i "s|^HOOKS=.*|HOOKS=(base udev autodetect keyboard modconf block encrypt lvm2 filesystems fsck)|g" /etc/mkinitcpio.conf
#here was "mkinitcpio -p linux" but it's used again after adding key to intmfs again
echo Set the root password
passwd
echo Installing grub 
pacman -S --noconfirm grub
echo Adding keys to GRUB configuration
echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub
export BLKID=$(blkid | grep sda3 | cut -d '"' -f 2)
export GRUBCMD="\"cryptdevice=UUID=$BLKID:cryptlvm root=/dev/vg/root cryptkey=rootfs:/root/secrets/crypto_keyfile.bin random.trust_cpu=on\""
echo GRUB_CMDLINE_LINUX=${GRUBCMD} >> /etc/default/grub

echo Installing efibootmanager and intel-ucode
pacman -S --noconfirm efibootmgr
pacman -S --noconfirm intel-ucode
echo Installing Boot to the mounted ESP for UEFI booting
grub-install --target=x86_64-efi --efi-directory=/efi --modules="tpm" --disable-shim-lock
echo generating GRUB configuration file
grub-mkconfig -o /boot/grub/grub.cfg
echo Creating a keyfile and adding it as LUKS key
mkdir /root/secrets && chmod 700 /root/secrets
head -c 512 /dev/urandom > /root/secrets/crypto_keyfile.bin && chmod 600 /root/secrets/crypto_keyfile.bin
cryptsetup -v luksAddKey -i 1 /dev/sda3 /root/secrets/crypto_keyfile.bin
echo Adding the keyfile to intramfs image
sed -i "s|^FILES=.*|FILES=(/root/secrets/crypto_keyfile.bin)|g" /etc/mkinitcpio.conf
echo Adding the keyfile to intramfs image
mkinitcpio -p linux
echo Regenerating GRUBs configuration file
grub-mkconfig -o /boot/grub/grub.cfg
chmod 700 /boot
echo please, "exit" and than "reboot"
