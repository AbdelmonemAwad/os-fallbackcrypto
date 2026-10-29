<?php

/*
 * SPDX-License-Identifier: BSD-2-Clause
 * Copyright (c) 2026 Abdelmonem Awad <eg2@live.com>
 */

namespace OPNsense\FallbackCrypto;

use OPNsense\Base\BaseModel;
use OPNsense\Base\Messages\Message;

class FallbackCrypto extends BaseModel
{
    /**
     * Which AES-GCM code ossl(4) takes on this processor: 'avx512', 'avx', 'none' or 'unknown'.
     *
     * The rule is ossl_cpuid()'s in ossl_x86.c (opnsense/src stable/26.7): AES-NI first, then VAES
     * with VPCLMULQDQ and AVX-512, or AVX with PCLMULQDQ and MOVBE. With neither, ossl takes no AES-GCM
     * session at all - not a slower one - and the kernel gives it to aesni, or to its plain software
     * when aesni is switched off. The features are those the kernel printed at boot; 'unknown' when
     * dmesg.boot has no Features2 line, as when the message buffer wrapped before it was kept, and
     * nothing is refused on that. status.py reads the same lines the same way for the page. The line
     * is looked for anywhere, not at the start of a line: 26.7's kernel begins every boot line with
     * [n], the CPU that printed it.
     */
    public static function osslGcm($dmesg = '/var/run/dmesg.boot')
    {
        $text = @file_get_contents($dmesg);
        if ($text === false || !preg_match('/Features2=0x[0-9a-f]+</', $text)) {
            return 'unknown';
        }
        $flags = [];
        preg_match_all(
            '/(?:Features2?|Structured Extended Features\d?|AMD Features2?)=0x[0-9a-f]+<([^>]*)>/',
            $text,
            $lists
        );
        foreach ($lists[1] as $list) {
            foreach (explode(',', $list) as $flag) {
                $flags[$flag] = true;
            }
        }
        if (empty($flags['AESNI'])) {
            return 'none';
        }
        if (!empty($flags['VAES']) && !empty($flags['VPCLMULQDQ']) && !empty($flags['AVX512F'])) {
            return 'avx512';
        }
        if (!empty($flags['AVX']) && !empty($flags['PCLMULQDQ']) && !empty($flags['MOVBE'])) {
            return 'avx';
        }
        return 'none';
    }

    /**
     * {@inheritdoc}
     *
     * "ossl only" is refused where ossl has no AES-GCM (2026-10-29): with aesni switched off, every
     * AES-GCM session - IPsec's usual cipher - would go to the kernel's plain software, slower than
     * either driver. An Atom or a Celeron without AVX is such a processor, and common in firewalls.
     * apply.php refuses it again, for a setting that reached config.xml some other way.
     */
    public function performValidation($validateFullModel = false)
    {
        $messages = parent::performValidation($validateFullModel);
        $mode = $this->general->mode;
        if (($validateFullModel || $mode->isFieldChanged()) && (string)$mode === 'only' && self::osslGcm() === 'none') {
            $messages->appendMessage(new Message(
                gettext('ossl has no AES-GCM on this processor (it needs AES-NI with AVX, PCLMULQDQ and MOVBE), so it cannot replace aesni.'),
                $mode->__reference
            ));
        }
        return $messages;
    }
}
