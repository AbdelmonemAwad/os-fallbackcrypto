#!/bin/sh
#-
# SPDX-License-Identifier: BSD-2-Clause
# Copyright (c) 2026 Abdelmonem Awad <eg2@live.com>
#
# Remove the Fallback Crypto plugin files. ossl stays loaded until the next boot, which no longer loads
# it. Kept: the settings, and the hint.aesni.0.disabled row in System: Settings: Tunables if the "only"
# setting wrote one - remove it there, or set the plugin back to "aesni only" and apply before
# removing it, or aesni stays off at every boot.
rm -f /usr/local/etc/rc.syshook.d/early/05-fallbackcrypto
rm -rf /usr/local/share/os-fallbackcrypto
rm -f /usr/local/opnsense/service/conf/actions.d/actions_fallbackcrypto.conf
rm -rf /usr/local/opnsense/scripts/fallbackcrypto
# the menu file place-menu.sh wrote, which is not one of src/'s files
rm -f /usr/local/opnsense/mvc/app/models/OPNsense/FallbackCrypto/Menu/Menu.xml
rmdir /usr/local/opnsense/mvc/app/models/OPNsense/FallbackCrypto/Menu 2>/dev/null || true
rm -rf /usr/local/opnsense/mvc/app/models/OPNsense/FallbackCrypto
rm -rf /usr/local/opnsense/mvc/app/controllers/OPNsense/FallbackCrypto
rm -rf /usr/local/opnsense/mvc/app/views/OPNsense/FallbackCrypto
service configd restart > /dev/null
# PHP keeps them in its own temporary directory on 26.7 (/var/lib/php/tmp); /tmp is where they were
rm -f /var/lib/php/tmp/opnsense_menu_cache.xml /var/lib/php/tmp/opnsense_acl_cache.json \
    /tmp/opnsense_menu_cache.xml /tmp/opnsense_acl_cache.json
if grep -q 'hint.aesni.0.disabled' /conf/config.xml 2>/dev/null; then
    echo "NOTE: hint.aesni.0.disabled is still in System: Settings: Tunables - aesni stays off until it is removed"
fi
echo "Fallback Crypto removed"
