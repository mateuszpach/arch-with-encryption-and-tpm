echo Make sure you are connected to the internet, you can follow the instructions in internet_connection.txt
echo Updating the system clock
timedatectl set-ntp true
echo Creating partitions
sgdisk --zap-all /dev/sda
sgdisk -n 1:0:+1MiB -t 1:ef02 /dev/sda
sgdisk -n 2:0:+550MiB -t 2:ef00 /dev/sda
sgdisk -n 3:0:0 -t 3:8309 /dev/sda
echo Creating the LUKS1 encrypted container on the Linux LUKS partition
cryptsetup luksFormat --type luks1 --use-random -S 1 -s 512 -h sha512 -i 5000 /dev/sda3
echo Opening the container
cryptsetup open /dev/sda3 cryptlvm
echo Preparing the logical volumes
echo Creating physical volume on top of the opened LUKS container
pvcreate /dev/mapper/cryptlvm
echo Creating the volume group and adding physical volume to it
vgcreate vg /dev/mapper/cryptlvm
echo Creating logical volumes on the volume group for swap, root and home
lvcreate -L 8G vg -n swap
lvcreate -L 32G vg -n root
lvcreate -l 100%FREE vg -n home
echo Formatting filesystems on each logical volume
mkfs.ext4 /dev/vg/root
mkfs.ext4 /dev/vg/home
mkswap /dev/vg/swap
echo Mounting filesystems
mount /dev/vg/root /mnt
mkdir /mnt/home
mount /dev/vg/home /mnt/home
swapon /dev/vg/swap
echo Preparing the EFI partition
echo Creating FAT32 filesystem on the EFI system partition
mkfs.fat -F32 /dev/sda2
echo Creating mountpoint for EFI sysyem partition at /efi for compatibility and mounting it
mkdir /mnt/efi
mount /dev/sda2 /mnt/efi
echo Installing necessary packages
pacstrap /mnt base linux linux-firmware mkinitcpio lvm2 vi dhcpcd wpa_supplicant vim iwd ntfs-3g
echo Configuring the system
echo Generating an fstab file
genfstab -U /mnt >> /mnt/etc/fstab
echo Entering new system chroot
echo Now you have to mount your pendrive or other device where you have all the scripts again.
arch-chroot /mnt
