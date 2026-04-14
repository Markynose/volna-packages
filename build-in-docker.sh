#!/bin/sh
# Build an APKBUILD inside Alpine and drop the result into pkghost.
# Usage: ./build-in-docker.sh <package-name>
set -e

PKGNAME="${1:?Usage: $0 <package-name>}"
VOLNA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKGDIR="$VOLNA_ROOT/packages/$PKGNAME"
OUTDIR="$VOLNA_ROOT/pkghost/packages/main/x86_64"
KEYDIR="$VOLNA_ROOT/pkghost/keys"
PRIVKEY="$KEYDIR/volna-signing.rsa"
PUBKEY="$KEYDIR/volna-signing.rsa.pub"

[ -f "$PKGDIR/APKBUILD" ] || { echo "No APKBUILD at $PKGDIR"; exit 1; }
[ -f "$PRIVKEY" ]         || { echo "No private key at $PRIVKEY"; exit 1; }

mkdir -p "$OUTDIR"

# Pre-stage cached tarball so abuild skips the download
[ -f /tmp/musl-1.2.6.tar.gz ] && cp /tmp/musl-1.2.6.tar.gz "$PKGDIR/" 2>/dev/null || true

INNERSCRIPT="$(dirname "$0")/docker-build-inner.sh"

docker run --rm \
  -v "$PKGDIR:/pkg:z" \
  -v "$OUTDIR:/out:z" \
  -v "$PRIVKEY:/root/.abuild/volna-signing.rsa:ro,z" \
  -v "$PUBKEY:/root/.abuild/volna-signing.rsa.pub:ro,z" \
  -v "$PUBKEY:/etc/apk/keys/volna-signing.rsa.pub:ro,z" \
  -v "$INNERSCRIPT:/build.sh:ro,z" \
  alpine:latest sh /build.sh

echo ""
echo "Packages written to: $OUTDIR"
ls -lh "$OUTDIR"/*.apk 2>/dev/null || echo "(no .apks — check above for errors)"
