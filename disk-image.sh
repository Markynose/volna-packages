#!/bin/sh
# Create a bootable Volna Linux disk image.
set -e

VOLNA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROOTFS="$VOLNA_ROOT/rootfs"
DISK="$VOLNA_ROOT/volna.img"
INNERSCRIPT="$(cd "$(dirname "$0")" && pwd)/disk-image-inner.sh"

# Create a blank 1 GB raw disk image
echo "==> Creating blank disk image (1 GB)..."
dd if=/dev/zero of="$DISK" bs=1M count=1024 status=progress

echo "==> Building disk image via Docker (privileged)..."
docker run --rm --privileged \
  -v "$DISK:/disk.img:z" \
  -v "$ROOTFS:/rootfs:ro,z" \
  -v "$INNERSCRIPT:/disk-image.sh:ro,z" \
  alpine:latest sh /disk-image.sh

echo ""
echo "==> Done. Image: $DISK"
ls -lh "$DISK"
