#!/bin/sh
# Runs INSIDE Alpine container. Populates /newroot with a bootable base system.
set -e

NEWROOT=/newroot
REPO_MAIN="https://dl-cdn.alpinelinux.org/alpine/edge/main"
REPO_COMM="https://dl-cdn.alpinelinux.org/alpine/edge/community"

echo ">>> Bootstrapping rootfs..."

# Seed Alpine signing keys and a bootstrap repositories file BEFORE
# running apk --root, so apk doesn't pick up our localhost:8080 entry
mkdir -p "$NEWROOT/etc/apk/keys"
cp /etc/apk/keys/*.pub "$NEWROOT/etc/apk/keys/"
printf '%s\n%s\n' "$REPO_MAIN" "$REPO_COMM" > "$NEWROOT/etc/apk/repositories"

# Install base packages into newroot
apk add \
  --root "$NEWROOT" \
  --initdb \
  --no-cache \
  musl busybox oksh runit apk-tools uutils-coreutils

echo ">>> Packages installed."

# -------- APK repos --------
# Add our Volna signing key alongside the Alpine keys
cp /volna-key.pub "$NEWROOT/etc/apk/keys/volna-signing.rsa.pub"

# Volna repo first; Alpine edge as fallback for packages not yet built
cat > "$NEWROOT/etc/apk/repositories" << 'EOF'
http://localhost:8080/packages/main
https://dl-cdn.alpinelinux.org/alpine/edge/main
EOF

# -------- User accounts --------
# Root password: "volna" — hash pre-computed with openssl passwd -6
HASH='$6$UiJFfw3tUoJdXFS.$yo7GFhKwKuYoLrkc1nJMJru9RDl0dKP2gYhu9LTpCRfdUqyacJKsP7PbWjwX8MGSPnlLSgcQCniWPcCBL5D81.'

cat > "$NEWROOT/etc/passwd" << EOF
root:x:0:0:root:/root:/usr/bin/oksh
EOF

cat > "$NEWROOT/etc/group" << 'EOF'
root:x:0:root
EOF

printf "root:%s:0:0:99999:7:::\n" "$HASH" > "$NEWROOT/etc/shadow"
chmod 640 "$NEWROOT/etc/shadow"

# -------- /sbin runit symlinks --------
# Alpine uses merged /usr so /sbin -> /usr/sbin on Alpine hosts.
# Our rootfs has a real /sbin/ (busybox lives there), so add runit symlinks.
ln -sf /usr/sbin/runit-init "$NEWROOT/sbin/init"
ln -sf /usr/sbin/runit      "$NEWROOT/sbin/runit"
ln -sf /usr/sbin/runit-init "$NEWROOT/sbin/runit-init"
ln -sf /usr/sbin/runsvdir   "$NEWROOT/sbin/runsvdir"
ln -sf /usr/sbin/sv         "$NEWROOT/sbin/sv"

# -------- fstab (virtio disk) --------
cat > "$NEWROOT/etc/fstab" << 'EOF'
/dev/vda1  /     ext4  defaults,noatime  0  1
proc       /proc proc  defaults          0  0
sysfs      /sys  sysfs defaults          0  0
tmpfs      /tmp  tmpfs defaults,noatime  0  0
EOF

# -------- runit stage 1: use absolute paths, be idempotent --------
cat > "$NEWROOT/etc/runit/1" << 'EOF'
#!/bin/sh
# runit stage 1 — one-time system initialization
PATH=/usr/sbin:/usr/bin:/sbin:/bin

# Mount pseudo-filesystems (kernel may have done devtmpfs already)
mount -t proc proc /proc 2>/dev/null || true
mount -t sysfs sysfs /sys 2>/dev/null || true
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true
mkdir -p /dev/pts
mount -t devpts devpts /dev/pts 2>/dev/null || true
mount -t tmpfs -o mode=0755,nosuid,nodev tmpfs /run 2>/dev/null || true

# Remount root rw
mount -o remount,rw / 2>/dev/null || true

# Hostname
[ -f /etc/hostname ] && hostname -F /etc/hostname

# pre-boot hooks
for f in /etc/rc.d/*.pre.boot; do [ -f "$f" ] && . "$f"; done

touch /dev/null 2>/dev/null || true
EOF
chmod +x "$NEWROOT/etc/runit/1"

# -------- runit stage 2: absolute path for runsvdir --------
cat > "$NEWROOT/etc/runit/2" << 'EOF'
#!/bin/sh
# runit stage 2 — service supervision
PATH=/usr/sbin:/usr/bin:/sbin:/bin

for f in /etc/rc.d/*.post.boot; do [ -f "$f" ] && . "$f"; done

exec /usr/sbin/runsvdir -P /var/service \
  'log: ......................................................................................'
EOF
chmod +x "$NEWROOT/etc/runit/2"

# -------- runit stage 3: absolute paths --------
cat > "$NEWROOT/etc/runit/3" << 'EOF'
#!/bin/sh
# runit stage 3 — shutdown
PATH=/usr/sbin:/usr/bin:/sbin:/bin

for f in /etc/rc.d/*.pre.shutdown; do [ -f "$f" ] && . "$f"; done

/usr/bin/sv stop /var/service/* 2>/dev/null || true
sync
umount -a -r 2>/dev/null || true

case "$1" in
    0) poweroff -f ;;
    6) reboot -f ;;
esac
EOF
chmod +x "$NEWROOT/etc/runit/3"

# -------- getty-tty1 service --------
mkdir -p "$NEWROOT/var/service/getty-tty1"
cat > "$NEWROOT/var/service/getty-tty1/run" << 'EOF'
#!/bin/sh
exec /sbin/getty 38400 tty1
EOF
chmod +x "$NEWROOT/var/service/getty-tty1/run"

# -------- /etc/shells --------
cat > "$NEWROOT/etc/shells" << 'EOF'
/bin/sh
/usr/bin/oksh
EOF

# -------- /etc/profile --------
cat > "$NEWROOT/etc/profile" << 'EOF'
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PS1='\u@\h:\w\$ '
umask 022
EOF

# -------- /etc/os-release --------
cat > "$NEWROOT/etc/os-release" << 'EOF'
ID=volna
NAME="Volna Linux"
PRETTY_NAME="Volna Linux (edge)"
HOME_URL="https://github.com/volna-linux"
EOF

# -------- root home --------
mkdir -p "$NEWROOT/root"
chmod 700 "$NEWROOT/root"
cat > "$NEWROOT/root/.profile" << 'EOF'
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PS1='\u@\h:\w\# '
EOF

# -------- mtab symlink --------
ln -sf /proc/mounts "$NEWROOT/etc/mtab" 2>/dev/null || true

echo ""
echo ">>> Bootstrap complete. Verifying key binaries:"
for b in /bin/ls /usr/bin/oksh /usr/sbin/runit-init /usr/bin/apk /sbin/getty /sbin/init; do
    if [ -e "$NEWROOT$b" ]; then
        echo "  OK  $b"
    else
        echo "  MISSING  $b"
    fi
done
