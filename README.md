# volna-packages

apk package repository for volna linux. built `.apk` files, apkindex, and apkbuild scripts.

## layout

- `packages/main/x86_64/` — built `.apk` files and `APKINDEX.tar.gz`
- `packages-src/` — apkbuild scripts per package
- `keys/` — repo signing public key
- `nginx.conf` — local dev server config

## serving locally

```
bash serve.sh   # starts nginx on localhost:8080
```

## building a package

```
bash build-in-docker.sh <pkgname>
```
