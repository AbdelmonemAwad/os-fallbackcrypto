#!/bin/sh
# Copyright (C) 2026 Abdelmonem Awad <eg2@live.com>. BSD 2-Clause License.
#
# Run by pkg(8) after the files of os-fallbackcrypto have been removed; not during an upgrade. ossl
# stays loaded until the next boot, which no longer loads it. Kept: the settings. Taken with the
# files: the hint.aesni.0.disabled row in System: Settings: Tunables that the "only" setting wrote,
# so aesni is back at the next boot; a row of that name written by hand stays, with a note.

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

# The row the "only" setting wrote goes with the plugin (2026-10-29). Left behind, it kept aesni
# switched off at every boot while nothing loaded ossl any more - the early hook went with the files -
# and every IPsec session went to the kernel's plain software. Only this plugin's rows are taken:
# hint.aesni.0.disabled with a description beginning "Fallback Crypto", as apply.php writes it; a
# row written by hand stays, with a note. loader.conf is then written again as apply.php writes it.
# The same lines are in install/uninstall.sh. Only where the early hook is gone: on an upgrade the
# plugin is still there, and post-install applies the saved setting again in any case.
if [ ! -e /usr/local/etc/rc.syshook.d/early/05-fallbackcrypto ]; then
	/usr/local/bin/php << 'PHP' || echo "NOTE: System: Settings: Tunables could not be read here - remove hint.aesni.0.disabled there if Fallback Crypto wrote it, or aesni stays off"
<?php
require_once 'config.inc';
require_once 'auth.inc';
require_once 'util.inc';
require_once 'system.inc';

$cfg = \OPNsense\Core\Config::getInstance();
$tunables = new \OPNsense\Core\Tunables();
$removed = 0;
$kept = 0;
foreach (iterator_to_array($tunables->item->iterateItems()) as $uuid => $item) {
    if ((string)$item->tunable !== 'hint.aesni.0.disabled') {
        continue;
    }
    if (strpos((string)$item->descr, 'Fallback Crypto') === 0) {
        $tunables->item->del($uuid);
        $removed++;
    } else {
        $kept++;
    }
}
if ($removed > 0) {
    /* validation off: a row of someone else's that the model would refuse must not keep this one */
    $tunables->serializeToConfig(false, true);
    $cfg->save();
    $config = $cfg->toArray(listtags());
    system_login_configure();
    echo "hint.aesni.0.disabled removed from System: Settings: Tunables - aesni attaches again at the next boot\n";
}
if ($kept > 0) {
    echo "NOTE: hint.aesni.0.disabled is still in System: Settings: Tunables, not written by Fallback Crypto - aesni stays off until it is removed\n";
}
PHP
fi
echo "Fallback Crypto removed"
