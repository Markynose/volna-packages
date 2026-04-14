#!/bin/sh
# Launch nginx to serve the Volna package repo on localhost:8080
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF="$SCRIPT_DIR/nginx.conf"

nginx -c "$CONF" -e stderr

echo "pkghost serving on http://localhost:8080/packages/main"
