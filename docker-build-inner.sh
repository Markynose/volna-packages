#!/bin/sh
# Runs INSIDE the Alpine container. Do not call directly.
set -e

apk add --no-cache alpine-sdk

mkdir -p /root/.abuild
cat > /root/.abuild/abuild.conf << 'CONF'
PACKAGER="Volna Linux <volna@volna.linux>"
PACKAGER_PRIVKEY="/root/.abuild/volna-signing.rsa"
CONF

cd /pkg
abuild -F -r

find /root/packages -name "*.apk" -exec cp {} /out/ \;

# Rebuild and sign APKINDEX.tar.gz
cd /out
apk index \
  --description "Volna Linux x86_64 main" \
  --rewrite-arch x86_64 \
  -o APKINDEX.tar.gz \
  *.apk
abuild-sign -k /root/.abuild/volna-signing.rsa APKINDEX.tar.gz

echo "Done. Contents of /out:"
ls -lh /out/
