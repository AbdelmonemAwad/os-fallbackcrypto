#!/bin/sh
#-
# SPDX-License-Identifier: BSD-2-Clause
# Copyright (c) 2026 Abdelmonem Awad <eg2@live.com>
#
# Install the Fallback Crypto plugin from a copy of this repository on the firewall:
#   sh install/install.sh
# Safe to run again after an update: settings in config.xml are kept. Nothing changes until a provider
# is chosen on the page and applied.

set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)

# plugin files: src/ maps to /usr/local
cp -R "${HERE}/src/" /usr/local/
chmod 755 /usr/local/opnsense/scripts/fallbackcrypto/*.py /usr/local/opnsense/scripts/fallbackcrypto/apply.php \
    /usr/local/opnsense/scripts/fallbackcrypto/place-menu.sh
chmod 644 /usr/local/opnsense/scripts/fallbackcrypto/i18n/ui/source.json
chmod 755 /usr/local/etc/rc.syshook.d/early/05-fallbackcrypto
chmod 644 /usr/local/opnsense/service/conf/actions.d/actions_fallbackcrypto.conf

# syntax check before anything is reloaded
for f in $(find "${HERE}/src" -name '*.php'); do
    php -l "$f" > /dev/null
done
for f in /usr/local/opnsense/scripts/fallbackcrypto/*.py; do
    python3 -m py_compile "$f"
done

# The page's place in the menu: the XGS section where os-xgs-npu is installed, VPN: IPsec where it
# is not. place-menu.sh writes the menu file and says which it chose: "xgs" or "own".
WHERE=$(/usr/local/opnsense/scripts/fallbackcrypto/place-menu.sh)

# reload configd actions, menu and ACL caches
service configd restart > /dev/null
# PHP keeps them in its own temporary directory on 26.7 (/var/lib/php/tmp); /tmp is where they were
rm -f /var/lib/php/tmp/opnsense_menu_cache.xml /var/lib/php/tmp/opnsense_acl_cache.json \
    /tmp/opnsense_menu_cache.xml /tmp/opnsense_acl_cache.json

# What this install is, for the self-update: the commit, from a git checkout, or from the
# .source-commit stamp that an xgs-image-builder image or the self-update leaves in the tree.
# Without either it is recorded as unknown, and the self-update takes the latest release once.
REV=; RDATE=; RSRC=unknown
if [ -e "${HERE}/.git" ] && REV=$(git -C "${HERE}" rev-parse HEAD 2>/dev/null); then
    RDATE=$(git -C "${HERE}" log -1 --format=%cI 2>/dev/null); RSRC=git
elif [ -s "${HERE}/.source-commit" ]; then
    read -r REV RDATE _ < "${HERE}/.source-commit"; RSRC=stamp
else
    REV=
fi
case ${REV} in *[!0-9a-f]*) REV=; RDATE=; RSRC=unknown ;; esac
install -d -m 0755 /usr/local/share/os-fallbackcrypto
printf '{"commit": "%s", "date": "%s", "source": "%s", "installed_at": %s}\n' \
    "${REV}" "${RDATE}" "${RSRC}" "$(date +%s)" > /usr/local/share/os-fallbackcrypto/installed.json

if [ "${WHERE}" = xgs ]; then
    echo "Fallback Crypto installed: XGS > Fallback Crypto"
else
    echo "Fallback Crypto installed: VPN > IPsec > Fallback Crypto"
fi
