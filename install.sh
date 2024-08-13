read -p "enter the disk on which to apply: " disk
read -p "enter the hostname for the setup: " hostname
read -p "enter the password for root: " password
read -p "enter the new user's name: " uname
read -p "password for the new user: " userpass
umount ${disk} 2>/dev/null
parted ${disk} mklabel gpt # clearing partition
parted ${disk} mkpart primary fat32 1MB 513MB # creating EFI
parted ${disk} set 1 esp on # assigning the EFI flag here

parted ${disk} mkpart primary ext4 513MB 210513MB # creating root partition
parted ${disk} mkpart primary linux-swap 210513MB 215513 # creating the swap partition here

partprobe ${disk} # inform the OS about changed partition table

#formatting partitions
mkfs.fat -F32 ${disk}1
mkfs.ext4 ${disk}2

# mount the root partition 
mount ${disk}2 /mnt/
mkdir -p /mnt/boot/
mount ${disk}1 /mnt/boot/
swapon ${disk}3

pacstrap -K /mnt base linux linux-firmware

# creating the table and saving inside the /mnt/etc/fstab
genfstab -U /mnt >> /mnt/etc/fstab


arch-chroot /mnt << EOF
echo ${hostname} >> /etc/hostname

useradd -a -G wheel -s /bin/bash ${username}
echo "${uname}:${userpass}" | chpasswd




pacman -Syu --noconfirm hyprland waybar wofi swaybg swaylock alacritty grim pulseaudio pulseaudio-ctl pavucontrol bluez bluez-utils networkmanager grub os-prober
systemctl restart NetworkManager
systemctl restart pulseaudio.service
systemctl restart bluetooth

echo "root:${password}" | chpasswd

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

exit
EOF

umount -R /mnt
# reboot








