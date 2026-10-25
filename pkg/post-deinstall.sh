#!/bin/sh
# Copyright (C) 2026 Abdelmonem Awad <eg2@live.com>. BSD 2-Clause License.
#
# Run by pkg(8) after the files of os-fallbackcrypto have been removed; not during an upgrade. ossl
# stays loaded until the next boot, which no longer loads it. Kept: the settings, and the
# hint.aesni.0.disabled row in System: Settings: Tunables if the "only" setting wrote one - aesni stays
# off at every boot until it is removed there.

if [ -x /usr/local/opnsense/scripts/firmware/register.php ]; then
	/usr/local/opnsense/scripts/firmware/register.php remove os-fallbackcrypto > /dev/null 2>&1 || true
fi

if [ -f /usr/local/etc/rc.d/configd ]; then
	/usr/local/etc/rc.d/configd restart
fi

if [ -f /usr/local/etc/rc.configure_plugins ]; then
	echo "Reloading plugin configuration"
	/usr/local/etc/rc.configure_plugins POST_DEINSTALL
fi

# The menu file place-menu.sh wrote is not one of the package's files, so pkg left it, and the
# model's directory with it. The menu is cached by PHP in /var/lib/php/tmp on 26.7, in /tmp before.
rm -f /usr/local/opnsense/mvc/app/models/OPNsense/FallbackCrypto/Menu/Menu.xml
rmdir /usr/local/opnsense/mvc/app/models/OPNsense/FallbackCrypto/Menu /usr/local/opnsense/mvc/app/models/OPNsense/FallbackCrypto 2>/dev/null || true
rm -f /var/lib/php/tmp/opnsense_menu_cache.xml /tmp/opnsense_menu_cache.xml

if grep -q 'hint.aesni.0.disabled' /conf/config.xml 2>/dev/null; then
	echo "NOTE: hint.aesni.0.disabled is still in System: Settings: Tunables - aesni stays off until it is removed"
fi
echo "Fallback Crypto removed"
