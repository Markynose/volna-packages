#!/bin/sh
# Runs INSIDE a --privileged Alpine container.
# Creates a partitioned, ext4-formatted, GRUB-installed bootable disk image.
set -e

DISK=/disk.img
ROOTFS=/rootfs
VMLINUZ=$(ls /rootfs/boot/vmlinuz-* 2>/dev/null | head -1)
KERNEL_VER=$(basename "$VMLINUZ" | sed 's/vmlinuz-//')

echo ">>> Installing tools..."
apk add --no-cache grub grub-bios e2fsprogs util-linux syslinux 2>/dev/null || \
apk add --no-cache grub grub-bios e2fsprogs util-linux

# Create loop devices if the container doesn't have them
for i in $(seq 0 7); do
    [ -e /dev/loop$i ] || mknod /dev/loop$i b 7 $i
done
[ -e /dev/loop-control ] || mknod /dev/loop-control c 10 237

echo ">>> Partitioning $DISK..."
# MBR partition table: one primary ext4 partition starting at 1 MiB
printf 'label: dos\nstart=2048, type=83, bootable\n' | sfdisk "$DISK"

# Set up loop devices for whole disk and partition
LOOP=$(losetup -f --show "$DISK")
echo ">>> Whole-disk loop: $LOOP"

# Partition loop: offset 1 MiB (2048 * 512) on the raw image file
LOOP_PART=$(losetup -f --show --offset $((2048 * 512)) "$DISK")
echo ">>> Partition loop: $LOOP_PART"

echo ">>> Formatting ext4..."
mkfs.ext4 -L volna-root -F "$LOOP_PART"

echo ">>> Mounting and copying rootfs..."
mkdir -p /mnt
mount "$LOOP_PART" /mnt

# Copy rootfs (preserving permissions, symlinks)
cp -a "$ROOTFS/." /mnt/

# Kernel should already be at /mnt/boot/vmlinuz-* from rootfs
echo ">>> Kernel in image: $(ls /mnt/boot/)"

# -------- GRUB --------
echo ">>> Installing GRUB..."
mkdir -p /mnt/boot/grub

grub-install \
  --target=i386-pc \
  --boot-directory=/mnt/boot \
  --no-floppy \
  "$LOOP"

echo ">>> Writing grub.cfg..."
cat > /mnt/boot/grub/grub.cfg << EOF
set default=0
set timeout=3

menuentry "Volna Linux $KERNEL_VER" {
    insmod part_msdos
    insmod ext2
    set root=(hd0,msdos1)
    linux /boot/$( basename "$VMLINUZ" ) root=/dev/vda1 rw \\
        init=/usr/sbin/runit-init \\
        console=ttyS0,115200 console=tty1 \\
        quiet
    boot
}
EOF

echo ">>> grub.cfg:"
cat /mnt/boot/grub/grub.cfg

sync
umount /mnt
losetup -d "$LOOP_PART"
losetup -d "$LOOP"

echo ""
echo ">>> Disk image ready: $DISK"
ls -lh "$DISK"
