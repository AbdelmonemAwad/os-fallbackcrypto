#!/bin/sh
# Copyright (C) 2026 Abdelmonem Awad <eg2@live.com>. BSD 2-Clause License.
#
# Run by pkg(8) after the files of os-fallbackcrypto are in place, on install and on upgrade alike.
# tools/make-package.sh inlines it into the package manifest. The first block and the registration
# are what every OPNsense plugin runs; the chmod lines and syntax checks of install/install.sh are
# not repeated, for the reasons os-netreport's post-install gives.

if [ -f /usr/local/etc/rc.d/configd ]; then
	/usr/local/etc/rc.d/configd restart
fi


if [ -f /usr/local/opnsense/mvc/script/run_migrations.php ]; then
	/usr/local/opnsense/mvc/script/run_migrations.php OPNsense/FallbackCrypto
fi

if [ -x /usr/local/opnsense/scripts/firmware/register.php ]; then
	/usr/local/opnsense/scripts/firmware/register.php install os-fallbackcrypto > /dev/null 2>&1 || true
fi

if [ -f /usr/local/etc/rc.configure_plugins ]; then
	echo "Reloading plugin configuration"
	/usr/local/etc/rc.configure_plugins POST_INSTALL
fi


# The page's place in the menu: the XGS section where os-xgs-npu is installed, VPN: IPsec where it
# is not. The menu file is not one of the package's files; place-menu.sh writes it and says which it
# chose.
WHERE=
if [ -x /usr/local/opnsense/scripts/fallbackcrypto/place-menu.sh ]; then
	WHERE=$(/usr/local/opnsense/scripts/fallbackcrypto/place-menu.sh) || WHERE=
fi
case "${WHERE}" in
xgs)	echo "Fallback Crypto installed: the page is at XGS > Fallback Crypto" ;;
own)	echo "Fallback Crypto installed: the page is at VPN > IPsec > Fallback Crypto" ;;
*)	echo "Fallback Crypto installed; its menu file was not written: run /usr/local/opnsense/scripts/fallbackcrypto/place-menu.sh" ;;
esac
