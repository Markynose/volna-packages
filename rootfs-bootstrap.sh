#!/bin/sh
# Populate rootfs/ with a working base system using Alpine as bootstrap.
set -e

VOLNA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROOTFS="$VOLNA_ROOT/rootfs"
PUBKEY="$VOLNA_ROOT/pkghost/keys/volna-signing.rsa.pub"
INNERSCRIPT="$(dirname "$0")/rootfs-bootstrap-inner.sh"

echo "==> Bootstrapping rootfs at $ROOTFS"

docker run --rm \
  -v "$ROOTFS:/newroot:z" \
  -v "$PUBKEY:/volna-key.pub:ro,z" \
  -v "$INNERSCRIPT:/bootstrap.sh:ro,z" \
  alpine:latest sh /bootstrap.sh

echo ""
echo "==> rootfs bootstrap done."
