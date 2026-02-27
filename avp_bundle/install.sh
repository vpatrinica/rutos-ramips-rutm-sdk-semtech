#!/bin/sh

# BasicStation and LoRa components
# Only operate on the packages that are actually part of the bundle.

set -e

echo "Installing packages from bundle $(pwd)..."

# remove any installed copy of each package (ignores errors)
for pkgfile in *.ipk; do
    pname=$(basename "$pkgfile" | cut -d_ -f1)
    echo "Removing old $pname if present..."
    opkg remove --force-depends "$pname" 2>/dev/null || true
    # Forcefully delete left-over config files that OPKG refuses to overwrite on next install
    if [ "$pname" = "vuci-app-basicstation-ui" ]; then
        rm -f /usr/share/vuci/menu.d/basicstation.json
    fi
done

# install all IPKs at once to allow OPKG to resolve dependencies automatically
echo "Installing all newly bundled packages..."
opkg install --force-maintainer *.ipk

echo "Reloading ACLs and restarting RPCD..."
ubus call session reload_acls
/etc/init.d/rpcd restart

 echo "Installation complete!"
