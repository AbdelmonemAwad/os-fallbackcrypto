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
 *   apply.php     print a JSON summary: status (ok or failed), steps, reboot, and detail - the
 *                 system's own words - when a step failed with some
 *
 * The steps are codes, in the order they happened, and the page puts them into words. Until
 * 2026-10-29 they were English sentences, and a page shown in Arabic showed them in English.
 *
 *   no_ossl_module    this kernel has no ossl.ko; nothing was changed (failed)
 *   no_aes_gcm        "only" where ossl has no AES-GCM; nothing was changed (failed)
 *   ossl_loaded       ossl loaded, or found loaded already
 *   ossl_not_loaded   kldload refused ossl; its words are the detail, and nothing was written (failed)
 *   ossl_stays        ossl is loaded and the setting no longer wants it: it stays until the next
 *                     boot, which does not load it
 *   hint_written      hint.aesni.0.disabled=1 written: aesni is switched off at the next boot
 *   hint_removed      hint.aesni.0.disabled removed: aesni attaches again at the next boot
 *   tunable_refused   the Tunables model refused the row; its words are the detail (failed)
 *   loader_written    loader.conf written again
 */

require_once 'config.inc';
require_once 'auth.inc';
require_once 'util.inc';
require_once 'system.inc';

/* The one JSON object the page reads, and the end of the script. */
function fc_answer($status, $steps, $reboot = false, $detail = '')
{
    $answer = ['status' => $status, 'steps' => $steps, 'reboot' => $reboot];
    if ($detail !== '') {
        $answer['detail'] = $detail;
    }
    echo json_encode($answer) . "\n";
    exit(0);
}

function fc_ossl_loaded()
{
    $rc = 1;
    $out = [];
    exec('/sbin/kldstat -q -n ossl', $out, $rc);
    return $rc === 0;
}

$cfg = \OPNsense\Core\Config::getInstance();
$mode = (string)(new \OPNsense\FallbackCrypto\FallbackCrypto())->general->mode;
$wants_ossl = $mode === 'alongside' || $mode === 'only';
$steps = [];

if ($wants_ossl) {
    if (!file_exists('/boot/kernel/ossl.ko')) {
        fc_answer('failed', ['no_ossl_module']);
    }
    /* "only" where ossl has no AES-GCM switches aesni off for nothing: every AES-GCM session would go
       to the kernel's plain software (2026-10-29). The model refuses it on the page; this refuses it
       for a setting that reached config.xml another way - restored, or saved before that refusal -
       before anything is loaded or written. */
    if ($mode === 'only' && \OPNsense\FallbackCrypto\FallbackCrypto::osslGcm() === 'none') {
        fc_answer('failed', ['no_aes_gcm']);
    }
    /* Until 2026-10-29 a refusal here was one step among the others, the answer still "ok", and
       "only" still wrote the loader line: aesni switched off at the next boot for a driver that had
       just failed to load, and would fail at that boot too if the cause was its own. */
    $rc = 0;
    $out = [];
    exec('/sbin/kldload -n ossl 2>&1', $out, $rc);
    if ($rc !== 0) {
        fc_answer('failed', ['ossl_not_loaded'], false, implode(' ', $out));
    }
    $steps[] = 'ossl_loaded';
} elseif (fc_ossl_loaded()) {
    $steps[] = 'ossl_stays';
}

$wanted = $mode === 'only';
$model = new \OPNsense\Core\Tunables();
$changed = false;
$found = null;
$hint_steps = [];
foreach (iterator_to_array($model->item->iterateItems()) as $uuid => $item) {
    if ((string)$item->tunable === 'hint.aesni.0.disabled') {
        if ($wanted) {
            $found = $item;
        } else {
            $model->item->del($uuid);
            $changed = true;
            $hint_steps = ['hint_removed'];
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
    $hint_steps = ['hint_written'];
}
if ($changed) {
    foreach ($model->performValidation() as $message) {
        fc_answer('failed', array_merge($steps, ['tunable_refused']), false, $message->getMessage());
    }
    $model->serializeToConfig();
    $cfg->save();
    /* system_login_configure() writes loader.conf from the legacy $config array, which config.inc
       filled when this script started - refreshed first, as os-xgs-npu's apply.php found it must be */
    $config = $cfg->toArray(listtags());
    system_login_configure();
    $steps = array_merge($steps, $hint_steps, ['loader_written']);
}

/*
 * Whether the setting is complete only after a reboot, read from what this boot set up (2026-10-29):
 * kenv holds the hints the loader passed, so a line written since does not show there yet - aesni off
 * at this boot or not, against the setting - and ossl loaded where the setting wants none, which keeps
 * it taking a share of the new sessions until the boot that does not load it. It was read from
 * whether aesni had attached, and a processor where aesni never attaches (no AES-NI and no SHA, as
 * qemu's default CPU) was told to reboot after every apply, while ossl left loaded was not.
 */
$hint_now = trim((string)shell_exec('/bin/kenv -q hint.aesni.0.disabled 2>/dev/null')) === '1';
$reboot = ($wanted !== $hint_now) || (!$wants_ossl && fc_ossl_loaded());

fc_answer('ok', $steps, $reboot);
