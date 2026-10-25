#!/usr/local/bin/python3
#-
# SPDX-License-Identifier: BSD-2-Clause
# Copyright (c) 2026 Abdelmonem Awad <eg2@live.com>
#
"""
What the page shows, as one JSON object: the host's processor and the features crypto depends on,
which AES-GCM code ossl(4) would use on it, the kernel's crypto providers present now, whether IPsec
is held to software providers, the setting and the tunable that goes with it, and the IPsec SAs the
host holds with their algorithms.

    status.py

Read only.
"""

import json
import os
import re
import subprocess
import xml.etree.ElementTree as ET

CONFIG = '/conf/config.xml'
DMESG = '/var/run/dmesg.boot'
FEATURES = ('AESNI', 'PCLMULQDQ', 'AVX', 'MOVBE', 'AVX2', 'SHA', 'AVX512F', 'VAES', 'VPCLMULQDQ')
PROVIDERS = ('aesni', 'ossl', 'ccp', 'qat', 'armv8crypto', 'safexcel')


def run(args):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=30).stdout
    except (OSError, subprocess.SubprocessError):
        return ''


def loaded(module):
    try:
        return subprocess.run(['/sbin/kldstat', '-q', '-n', module], timeout=10).returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def processor():
    try:
        text = open(DMESG, encoding='utf-8', errors='replace').read()
    except OSError:
        text = ''
    model = re.search(r'CPU: (.+?)\s+\(', text)
    flags = set()
    for line in re.findall(r'(?:Features2?|Structured Extended Features\d?|AMD Features2?)=0x[0-9a-f]+<([^>]*)>', text):
        flags.update(line.split(','))
    return (model.group(1).strip() if model else run(['/sbin/sysctl', '-n', 'hw.model']).strip(),
            {f: f in flags for f in FEATURES})


def gcm_path(f):
    """Which AES-GCM ossl's ossl_x86.c takes on this processor (opnsense/src stable/26.7)."""
    if not f['AESNI']:
        return 'none'
    if f['VAES'] and f['VPCLMULQDQ'] and f['AVX512F']:
        return 'avx512'
    if f['AVX'] and f['PCLMULQDQ'] and f['MOVBE']:
        return 'avx'
    return 'none'


def sas():
    """The SAs in the kernel's database, each with its encryption and authentication."""
    out = []
    current = None
    for line in run(['/sbin/setkey', '-D']).splitlines():
        if line and not line[0].isspace() and re.match(r'^[0-9a-fA-F:.]+ [0-9a-fA-F:.]+$', line.strip()):
            current = {'pair': line.strip(), 'enc': '', 'auth': ''}
            out.append(current)
        elif current is not None:
            enc = re.search(r'^\s*E: (\S+)', line)
            auth = re.search(r'^\s*A: (\S+)', line)
            if enc:
                current['enc'] = enc.group(1)
            if auth:
                current['auth'] = auth.group(1)
    return out


def main():
    model, features = processor()
    try:
        root = ET.parse(CONFIG).getroot()
        mode = root.findtext('OPNsense/FallbackCrypto/general/mode') or 'off'
        tunable = any((item.findtext('tunable') or '') == 'hint.aesni.0.disabled'
                      for item in root.findall('sysctl/item'))
    except (OSError, ET.ParseError):
        mode, tunable = 'off', False
    providers = {}
    for name in PROVIDERS:
        desc = run(['/sbin/sysctl', '-n', 'dev.%s.0.%%desc' % name]).strip()
        if desc:
            providers[name] = desc
    support = run(['/sbin/sysctl', '-n', 'net.inet.ipsec.crypto_support']).strip()
    print(json.dumps({
        'processor': model,
        'features': features,
        'ossl_gcm': gcm_path(features),
        'ossl_available': os.path.exists('/boot/kernel/ossl.ko'),
        'ossl_loaded': loaded('ossl'),
        'providers': providers,
        'software_only': support == '33554432',
        'aesni_disabled_next_boot': tunable,
        'aesni_disabled_now': run(['/bin/kenv', '-q', 'hint.aesni.0.disabled']).strip() == '1',
        'mode': mode,
        'sas': sas(),
    }))


if __name__ == '__main__':
    main()
