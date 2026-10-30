#!/bin/sh
#-
# SPDX-License-Identifier: BSD-2-Clause
# Copyright (c) 2026 Abdelmonem Awad <eg2@live.com>
#
# Remove the Fallback Crypto plugin files. ossl stays loaded until the next boot, which no longer loads
# it. Kept: the settings. Taken with the files: the hint.aesni.0.disabled row in System: Settings:
# Tunables that the "only" setting wrote, so aesni is back at the next boot; a row of that name
# written by hand stays, with a note.
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

# The row the "only" setting wrote goes with the plugin (2026-10-29). Left behind, it kept aesni
# switched off at every boot while nothing loaded ossl any more - the early hook went with the files -
# and every IPsec session went to the kernel's plain software. Only this plugin's rows are taken:
# hint.aesni.0.disabled with a description beginning "Fallback Crypto", as apply.php writes it; a
# row written by hand stays, with a note. loader.conf is then written again as apply.php writes it.
# The same lines are in pkg/post-deinstall.sh.
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
echo "Fallback Crypto removed"
