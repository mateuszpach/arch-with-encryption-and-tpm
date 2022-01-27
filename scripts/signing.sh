echo Installing efitools
pacman -S --noconfirm efitools
echo Creating a GUID for owner identification
uuidgen --random > GUID.txt
echo Setting Platform Key
openssl req -newkey rsa:4096 -nodes -keyout PK.key -new -x509 -sha256 -days 3650 -subj "/CN=my Platform Key/" -out PK.crt
openssl x509 -outform DER -in PK.crt -out PK.cer
cert-to-efi-sig-list -g "$(< GUID.txt)" PK.crt PK.esl
sign-efi-sig-list -g "$(< GUID.txt)" -k PK.key -c PK.crt PK PK.esl PK.auth
sign-efi-sig-list -g "$(< GUID.txt)" -c PK.crt -k PK.key PK /dev/null rm_PK.auth
echo Setting Key Exchange Key
openssl req -newkey rsa:4096 -nodes -keyout KEK.key -new -x509 -sha256 -days 3650 -subj "/CN=my Key Exchange Key/" -out KEK.crt
openssl x509 -outform DER -in KEK.crt -out KEK.cer
cert-to-efi-sig-list -g "$(< GUID.txt)" KEK.crt KEK.esl
sign-efi-sig-list -g "$(< GUID.txt)" -k PK.key -c PK.crt KEK KEK.esl KEK.auth
echo Setting Signature Database Key
openssl req -newkey rsa:4096 -nodes -keyout db.key -new -x509 -sha256 -days 3650 -subj "/CN=my Signature Database key/" -out db.crt
openssl x509 -outform DER -in db.crt -out db.cer
cert-to-efi-sig-list -g "$(< GUID.txt)" db.crt db.esl
sign-efi-sig-list -g "$(< GUID.txt)" -k KEK.key -c KEK.crt db db.esl db.auth
echo Installing sbsigntools
pacman -S --noconfirm sbsigntools
echo Signing bootloader and kernel
sbsign --key db.key --cert db.crt --output /boot/vmlinuz-linux /boot/vmlinuz-linux
sbsign --key db.key --cert db.crt --output /efi/EFI/arch/grubx64.efi /efi/EFI/arch/grubx64.efi
echo Craeting hooks to automatically sign bootloader and kernel on install and updates
mkdir -p /etc/pacman.d/hooks
cp /root/scripts-stick/scripts/99-secureboot-linux.hook /etc/pacman.d/hooks/99-secureboot-linux.hook
cp /root/scripts-stick/scripts/98-secureboot-grub.hook /etc/pacman.d/hooks/98-secureboot-grub.hook
echo Moving KeyTool and keys to stick
mkdir -p /root/scripts-stick/EFI/BOOT/
cp /usr/share/efitools/efi/KeyTool.efi /root/scripts-stick/EFI/BOOT/bootx64.efi
cp /root/*.cer /root/*.esl /root/*.auth /root/scripts-stick/

echo Boot into firmware setup utility and setup new key following the guide
