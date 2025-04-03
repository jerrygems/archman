read -p "enter the disk on which to apply(e.g. /dev/sdx) : " disk
read -p "enter the efi partition size(e.g. 512 Integer) :" efi_size
read -p "enter the swap partition size(e.g. 4096 Integer) :" swap_size
read -p "enter the hostname for the setup(e.g. anyname) : " hostname
read -p "enter the password for root(e.g. @p455w0rd123) : " password
read -p "enter the new user's name : " username
read -p "password for the new user : " userpass
read -p "enter the country name : " country

reflector --country $country --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
pacman -Syyu
sudo sed -i 's/^#ParallelDownloads = [0-9]\+/ParallelDownloads = 15/' /etc/pacman.conf

umount -R /mnt || true
umount -R "${disk}"* 2>/dev/null || true
umount -R "${disk}" 2>/dev/null || true

if ! [[ -b "$disk" ]]; then
  echo "Specified invalid disk. Please specify correct disk.";
  exit 1;
fi

if ! [[ "$efi_size" =~ ^[0-9]+$ ]]; then
  echo "only integer should be specified for EFI partition.";
  exit 1;
fi

if ! [[ "$swap_size" =~ ^[0-9]+$ ]]; then 
  echo "only integer should be specified for the swap partition";
  exit 1;
fi

disk_size=$(echo "($(lsblk -bndo SIZE ${disk})/1024/1024)-1" | bc) # MB
EFI_PART=$efi_size # MB
SWAP_PART=$swap_size # MB
echo -e "[ DISK SIZE\t\t<==>\t\t[$disk_size] ] \n[ EFI PARTITION\t\t<==>\t\t[$EFI_PART] ] \n[ SWAP PARTITION\t\t<==>\t\t[$SWAP_PART] ]";

parted ${disk} mklabel gpt # clearing partition
if [[ $? -ne 0 ]]; then echo "Failed while clearing partition"; exit 1; fi


parted ${disk} mkpart primary fat32 1MiB ${EFI_PART}MiB # creating EFI
if [[ $? -ne 0 ]]; then echo "Failed while creating EFI"; exit 1; fi

parted ${disk} set 1 esp on # assigning the EFI flag here
if [[ $? -ne 0 ]]; then echo "Failed while assigning the EFI flag"; exit 1; fi

parted ${disk} mkpart primary linux-swap ${EFI_PART}MiB $(echo ${EFI_PART}+${SWAP_PART} | bc)MiB # creating the swap partition here
if [[ $? -ne 0 ]]; then echo "Failed while creating the swap partition"; exit 1; fi

parted ${disk} mkpart primary ext4 $(echo "${EFI_PART}+${SWAP_PART}" | bc)MiB ${disk_size}MiB # creating root partition
if [[ $? -ne 0 ]]; then echo "Failed while creating the ROOT partition"; exit 1; fi

partprobe ${disk} # inform the OS about changed partition table
if [[ $? -ne 0 ]]; then echo "Failed while applying changes for the partitions"; exit 1; fi

#formatting partitions
mkfs.fat -F32 ${disk}1
mkswap ${disk}2
mkfs.ext4 ${disk}3
if [[ $? -ne 0 ]]; then echo "Failed while formatting partition."; exit 1; fi

# mount the root partition 
mount ${disk}3 /mnt/
mkdir -p /mnt/boot/
mount ${disk}1 /mnt/boot/
swapon ${disk}2

pacstrap -K /mnt base linux linux-firmware hyprland waybar wofi swaybg swaylock alacritty grim pulseaudio pavucontrol bluez bluez-utils networkmanager archlinux-keyring sddm sudo nano neovim

# creating the table and saving inside the /mnt/etc/fstab
genfstab -U /mnt >> /mnt/etc/fstab
if [[ $? -ne 0 ]]; then echo "Failed while saving the generated file system table for permanent changes"; exit 1; fi

arch-chroot /mnt << EOF
pacman -Sy
echo ${hostname} >> /etc/hostname
useradd -m -G wheel,users,video,audio,storage,power -s /bin/bash ${username}
echo "${username}:${userpass}" | chpasswd


pacman -Sy --noconfirm archlinux-keyring

rm -r /etc/pacman.d/gnupg
pacman-key --init
pacman-key --populate archlinux
pacman -Syu


pacman -S --noconfirm grub efibootmgr
systemctl restart sddm
systemctl restart NetworkManager
systemctl restart pulseaudio.service
systemctl restart bluetooth

echo "root:${password}" | chpasswd

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

exit
EOF

#umount -R /mnt
#reboot








