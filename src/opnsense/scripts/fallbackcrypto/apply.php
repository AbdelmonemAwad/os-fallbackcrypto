#!/usr/local/bin/php
<?php

/*
 * SPDX-License-Identifier: BSD-2-Clause
 * Copyright (c) 2026 Abdelmonem Awad <eg2@live.com>
 *
 * Put the setting where it takes effect:
 *
 *   off        nothing loaded by this plugin; the loader line that switches aesni off is removed
 *   alongside  ossl(4) loaded now and at every boot (early/05-fallbackcrypto); new IPsec sessions are
 *              shared by the kernel between aesni and ossl
 *   only       the same, and aesni switched off at the loader (hint.aesni.0.disabled=1), so from the
 *              next boot every session is ossl's
 *
 * The loader line goes through OPNsense's own Tunables model, as os-xgs-npu's settings do, so it is
 * visible under System: Settings: Tunables, and loader.conf is written by the function the Tunables
 * page's apply runs. A session already open keeps its provider: the change reaches a tunnel when its
 * SAs are next made - at a rekey, or at once by restarting IPsec - and aesni goes only at a reboot.
 *
 *   apply.php     print a JSON summary
 */

require_once 'config.inc';
require_once 'auth.inc';
require_once 'util.inc';
require_once 'system.inc';

$cfg = \OPNsense\Core\Config::getInstance();
$mode = (string)(new \OPNsense\FallbackCrypto\FallbackCrypto())->general->mode;
$steps = [];
$reboot = false;

if ($mode === 'alongside' || $mode === 'only') {
    if (!file_exists('/boot/kernel/ossl.ko')) {
        echo json_encode(['status' => 'failed', 'steps' => ['this kernel has no ossl.ko']]) . "\n";
        exit(0);
    }
    $rc = 0;
    $out = [];
    exec('/sbin/kldload -n ossl 2>&1', $out, $rc);
    $steps[] = $rc === 0 ? 'ossl loaded' : 'ossl could not be loaded: ' . implode(' ', $out);
} else {
    $steps[] = 'ossl stays as it is until the next boot, which does not load it';
}

$wanted = $mode === 'only';
$model = new \OPNsense\Core\Tunables();
$changed = false;
$found = null;
foreach (iterator_to_array($model->item->iterateItems()) as $uuid => $item) {
    if ((string)$item->tunable === 'hint.aesni.0.disabled') {
        if ($wanted) {
            $found = $item;
        } else {
            $model->item->del($uuid);
            $changed = true;
            $steps[] = 'hint.aesni.0.disabled removed: aesni attaches at the next boot';
        }
    }
}
if ($wanted && $found === null) {
    $found = $model->item->Add();
    $found->tunable = 'hint.aesni.0.disabled';
    $found->descr = 'Fallback Crypto - aesni off, so IPsec takes ossl';
    $changed = true;
}
if ($wanted && (string)$found->value !== '1') {
    $found->value = '1';
    $changed = true;
    $steps[] = 'hint.aesni.0.disabled=1: aesni is switched off at the next boot';
}
if ($changed) {
    foreach ($model->performValidation() as $message) {
        echo json_encode(['status' => 'failed', 'steps' => ['tunable refused: ' . $message->getMessage()]]) . "\n";
        exit(0);
    }
    $model->serializeToConfig();
    $cfg->save();
    /* system_login_configure() writes loader.conf from the legacy $config array, which config.inc
       filled when this script started - refreshed first, as os-xgs-npu's apply.php found it must be */
    $config = $cfg->toArray(listtags());
    system_login_configure();
    $steps[] = 'loader.conf written';
}

$aesni_now = trim((string)shell_exec('/sbin/sysctl -n dev.aesni.0.%desc 2>/dev/null')) !== '';
$reboot = ($wanted && $aesni_now) || (!$wanted && !$aesni_now);

echo json_encode(['status' => 'ok', 'steps' => $steps, 'reboot' => $reboot]) . "\n";
