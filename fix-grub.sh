#!/bin/bash
# Re-installs GRUB from the host into volna.img.
# Run with: sudo bash pkghost/fix-grub.sh
set -e

VOLNA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DISK="$VOLNA_ROOT/volna.img"
MNT="$(mktemp -d)"

echo "==> Setting up loop devices..."
LOOP_DISK=$(losetup -f --show "$DISK")
LOOP_PART=$(losetup -f --show --offset $((2048 * 512)) "$DISK")
echo "    Disk : $LOOP_DISK"
echo "    Part : $LOOP_PART"

echo "==> Mounting partition..."
mount "$LOOP_PART" "$MNT"

echo "==> Removing stale grub directories from Docker install..."
rm -rf "$MNT/boot/grub" "$MNT/boot/grub2"

echo "==> Running grub2-install (host tools, modules embedded in core.img)..."
grub2-install \
  --target=i386-pc \
  --boot-directory="$MNT/boot" \
  --no-floppy \
  --modules="part_msdos ext2 linux normal search search_fs_uuid" \
  "$LOOP_DISK"

echo "==> Rewriting grub.cfg..."
VMLINUZ=$(ls "$MNT/boot/vmlinuz-"* | head -1 | xargs basename)
cat > "$MNT/boot/grub2/grub.cfg" << EOF
set default=0
set timeout=3

menuentry "Volna Linux" {
    insmod part_msdos
    insmod ext2
    set root=(hd0,msdos1)
    linux /boot/${VMLINUZ} root=/dev/vda1 rw \\
        init=/usr/sbin/runit-init \\
        earlyprintk=serial,ttyS0,115200 \\
        console=ttyS0,115200 console=tty1
    boot
}
EOF
echo "==> grub.cfg written to $MNT/boot/grub2/grub.cfg:"
cat "$MNT/boot/grub2/grub.cfg"

echo "==> Boot directory after install:"
find "$MNT/boot" -type f | sort

sync
umount "$MNT"
rmdir "$MNT"
losetup -d "$LOOP_PART"
losetup -d "$LOOP_DISK"

echo ""
echo "==> Done. GRUB re-installed from host."
