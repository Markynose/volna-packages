#!/bin/bash
# Patch runit stage scripts into the existing image without a full rebuild.
# Run with: sudo bash pkghost/patch-image.sh
set -e

VOLNA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DISK="$VOLNA_ROOT/volna.img"
ROOTFS="$VOLNA_ROOT/rootfs"
MNT="$(mktemp -d)"

echo "==> Mounting image..."
LOOP=$(losetup -f --show --offset $((2048 * 512)) "$DISK")
echo "    Loop: $LOOP"
mount "$LOOP" "$MNT"

echo ""
echo "==> Current /var/service in image:"
ls -la "$MNT/var/service/" || echo "  (empty or missing)"

echo ""
echo "==> Current /var/service/getty-ttyS0 in image:"
ls -la "$MNT/var/service/getty-ttyS0/" 2>/dev/null || echo "  MISSING"

echo ""
echo "==> Patching runit stage scripts..."
cp -v "$ROOTFS/etc/runit/1"  "$MNT/etc/runit/1"
cp -v "$ROOTFS/etc/runit/2"  "$MNT/etc/runit/2"

echo ""
echo "==> Syncing and unmounting..."
sync
umount "$MNT"
rmdir "$MNT"
losetup -d "$LOOP"

echo ""
echo "==> Done."
