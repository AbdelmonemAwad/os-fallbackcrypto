{#
 # SPDX-License-Identifier: BSD-2-Clause
 # Copyright (c) 2026 Abdelmonem Awad <eg2@live.com>
 #
 # VPN: IPsec: Fallback Crypto (XGS: Fallback Crypto when os-xgs-npu is installed) - the host's
 # processor, its crypto providers, the SAs it holds, and the choice of provider for them.
 #}

<style>
    /* KIT-CSS-BEGIN */
    .xgs-cards { display: flex; flex-wrap: wrap; gap: 12px; padding: 15px; }
    .xgs-cards.xgs-top { padding: 0 0 15px; }
    .xgs-card { flex: 1 1 200px; min-width: 190px; border: 1px solid rgba(128, 128, 128, 0.25);
                border-inline-start: 4px solid #9e9e9e; border-radius: 3px; padding: 10px 14px;
                background-color: rgba(128, 128, 128, 0.04); }
    .xgs-card.ok { border-inline-start-color: #5cb85c; }
    .xgs-card.warn { border-inline-start-color: #f0ad4e; }
    .xgs-card.bad { border-inline-start-color: #d9534f; }
    .xgs-card .k { font-size: 11px; text-transform: uppercase; letter-spacing: .04em; opacity: 0.6; }
    .xgs-card .v { font-size: 19px; font-weight: 600; line-height: 1.3; margin: 2px 0; }
    .xgs-card .s { font-size: 12px; opacity: 0.7; }
    .xgs-card .fa { opacity: 0.35; float: inline-end; font-size: 18px; margin-top: 2px; }
    .xgs-head { padding-top: 5px; padding-bottom: 5px; font-size: 16px; }
    /* KIT-CSS-END */
</style>

<script>
    $(document).ready(function () {
        /* KIT-JS-BEGIN */
        /* A string as OPNsense's API and Volt's lang._() hand it over - escaped - made plain for .text(). */
        function plain(value) {
            return $('<textarea/>').html(value === null || value === undefined ? '' : String(value)).text();
        }

        /* One card: cls '' (grey, no judgement), 'ok', 'warn' or 'bad'; icon a Font Awesome name. */
        function card(cls, icon, key, value, sub) {
            return $('<div class="xgs-card"/>').addClass(cls)
                .append($('<i class="fa"/>').addClass(icon))
                .append($('<div class="k"/>').text(plain(key)))
                .append($('<div class="v"/>').text(plain(value)))
                .append($('<div class="s"/>').text(plain(sub || ' ')));
        }

        /* Until the first reading: the same cards, their keys, and an ellipsis for every value. */
        function cards_wait(target, keys) {
            $(target).empty();
            $.each(keys, function (i, key) {
                $(target).append(card('', 'fa-ellipsis-h', key, '…', ''));
            });
        }

        /* The selected tab kept in the address, as on OPNsense's own tabbed pages. */
        function keep_tab() {
            if (window.location.hash !== '') {
                $('a[href="' + window.location.hash + '"]').tab('show');
            }
            $('.nav-tabs a').on('shown.bs.tab', function (e) {
                history.pushState(null, null, e.target.hash);
            });
        }
        /* KIT-JS-END */

        const gcm = {
            'avx512': "{{ lang._('ossl: AES-GCM with AVX-512 and VAES') }}",
            'avx': "{{ lang._('ossl: AES-GCM with AVX, PCLMULQDQ and MOVBE') }}",
            'none': "{{ lang._('ossl: no AES-GCM here') }}",
            'unknown': "{{ lang._('Features unknown') }}"
        };

        /* apply.php's steps arrive as codes and are put into words here, so they are in the page's
           language (2026-10-29); a code this page does not know is shown as it came. */
        const said = {
            'no_ossl_module': "{{ lang._('No ossl module in this kernel') }}",
            'no_aes_gcm': "{{ lang._('ossl has no AES-GCM on this processor (it needs AES-NI with AVX, PCLMULQDQ and MOVBE), so it cannot replace aesni.') }}",
            'ossl_loaded': "{{ lang._('ossl loaded') }}",
            'ossl_not_loaded': "{{ lang._('ossl could not be loaded') }}",
            'ossl_stays': "{{ lang._('ossl stays loaded until next boot') }}",
            'hint_written': "{{ lang._('hint.aesni.0.disabled=1: aesni off from next boot') }}",
            'hint_removed': "{{ lang._('hint.aesni.0.disabled removed: aesni back at next boot') }}",
            'tunable_refused': "{{ lang._('Tunable refused') }}",
            'loader_written': "{{ lang._('loader.conf written') }}"
        };

        function draw(data) {
            const $cards = $('#fc-cards').empty();
            if (!data || data.error) {
                $cards.append(card('bad', 'fa-lock', "{{ lang._('Fallback Crypto') }}", "{{ lang._('Status unreadable') }}", ''));
                return;
            }
            /* A warning where ossl has no AES-GCM, which is also where "ossl only" is refused, or
               where there is no AES-NI and neither driver does AES; no judgement where dmesg.boot
               names no features (2026-10-29). Before, such a processor had a grey card. */
            const cpu = data.ossl_gcm === 'none' ? 'warn' : (data.ossl_gcm === 'unknown' ? '' : 'ok');
            $cards.append(card(cpu, 'fa-microchip', "{{ lang._('Processor') }}", data.processor,
                data.ossl_gcm === 'none' && !data.features.AESNI ? "{{ lang._('No AES-NI') }}" : gcm[data.ossl_gcm]));
            const names = Object.keys(data.providers);
            $cards.append(card(names.length ? 'ok' : 'warn', 'fa-cubes', "{{ lang._('Crypto providers') }}",
                names.length ? names.join(', ') : "{{ lang._('none') }}",
                data.software_only ? "{{ lang._('IPsec held to software providers') }}" : ''));
            const algos = {};
            data.sas.forEach(function (s) { algos[s.enc || '-'] = (algos[s.enc || '-'] || 0) + 1; });
            $cards.append(card('', 'fa-exchange', "{{ lang._('IPsec SAs') }}", String(data.sas.length),
                Object.keys(algos).map(function (a) { return a + ' ' + algos[a]; }).join(', ')));
            /* The setting against what runs (2026-10-29). Applied: ossl loaded where the setting wants
               it, and the loader line written exactly where it wants aesni off. Then in effect, or
               waiting for the boot that switches aesni off or on again, or that leaves out an ossl no
               longer wanted - loaded, it keeps taking a share of the new sessions. Until then only
               aesni at this boot was compared, and a setting saved but never applied, or "aesni only"
               with ossl still loaded, read as in effect. */
            const wants_ossl = data.mode === 'alongside' || data.mode === 'only';
            const wants_off = data.mode === 'only';
            let state = 'effect';
            if ((wants_ossl && !data.ossl_loaded) || wants_off !== !!data.aesni_disabled_next_boot) {
                state = 'apply';
            } else if (wants_off !== !!data.aesni_disabled_now || (!wants_ossl && data.ossl_loaded)) {
                state = 'reboot';
            }
            $cards.append(card(state === 'effect' ? 'ok' : 'warn', 'fa-power-off', "{{ lang._('Next boot') }}",
                data.mode === 'only' ? "{{ lang._('ossl only') }}" : (data.mode === 'alongside' ? "{{ lang._('ossl beside aesni') }}" : "{{ lang._('aesni only') }}"),
                {'apply': "{{ lang._('Apply needed') }}", 'reboot': "{{ lang._('Reboot needed') }}",
                    'effect': "{{ lang._('In effect') }}"}[state]));
            $('#fc-noossl').toggle(!data.ossl_available);

            const $f = $('#fc-features tbody').empty();
            Object.keys(data.features).forEach(function (k) {
                $f.append($('<tr/>').append($('<td/>').append($('<code/>').text(k)))
                    .append($('<td/>').text(data.features[k] ? "{{ lang._('yes') }}" : "{{ lang._('no') }}")));
            });
            if (!Object.keys(data.features).length) {
                $f.append($('<tr/>').append($('<td colspan="2" class="text-muted"/>').text(plain("{{ lang._('Features unknown') }}"))));
            }
            const $s = $('#fc-sas tbody').empty();
            data.sas.forEach(function (s) {
                $s.append($('<tr/>').append($('<td/>').append($('<code/>').text(s.pair)))
                    .append($('<td/>').text(s.enc)).append($('<td/>').text(s.auth)));
            });
            if (!data.sas.length) {
                $s.append($('<tr/>').append($('<td colspan="3" class="text-muted"/>').text(plain("{{ lang._('No IPsec SAs') }}"))));
            }
        }

        /* One status feeds the cards and both tables. */
        function refresh() {
            ajaxGet('/api/fallbackcrypto/service/status', {}, draw);
        }

        mapDataToFormUI({'frm_general': '/api/fallbackcrypto/settings/get'}).done(function () {
            $('.selectpicker').selectpicker('refresh');
        });
        cards_wait('#fc-cards', ["{{ lang._('Processor') }}", "{{ lang._('Crypto providers') }}",
            "{{ lang._('IPsec SAs') }}", "{{ lang._('Next boot') }}"]);
        refresh();

        $('#refreshAct').click(function () {
            refresh();
        });

        $('#saveAct').click(function () {
            const $button = $(this).prop('disabled', true);
            const $progress = $('#frm_general_progress').addClass('fa fa-spinner fa-pulse');
            const done = function () {
                $progress.removeClass('fa fa-spinner fa-pulse');
                $button.prop('disabled', false);
            };
            saveFormToEndpoint('/api/fallbackcrypto/settings/set', 'frm_general', function () {
                ajaxCall('/api/fallbackcrypto/service/apply', {}, function (data) {
                    done();
                    const words = (data && data.steps ? data.steps : []).map(function (code) {
                        return plain(said[code] || code);
                    });
                    /* the system's own words for a step that failed (kldload's, the Tunables model's),
                       and the API's when there was no answer to read */
                    if (data && (data.detail || data.error)) {
                        words.push(plain(data.detail || data.error));
                    }
                    $('#fc-result').attr('class', data && data.status === 'ok' ? 'alert alert-success' : 'alert alert-danger')
                        .text(words.join(' · ')).show();
                    $('#fc-reboot').toggle(!!(data && data.reboot));
                    refresh();
                });
            }, false, done);
        });
    });
</script>

<div class="xgs-cards xgs-top" id="fc-cards"></div>
<div class="clearfix" style="margin-bottom: 10px;">
    <button id="refreshAct" class="btn btn-default btn-xs pull-right" type="button" title="{{ lang._('Refresh') }}"><i class="fa fa-fw fa-refresh"></i></button>
</div>

<div id="fc-noossl" class="alert alert-warning" role="alert" style="display: none;">
    {{ lang._('No ossl module in this kernel') }}
</div>

<div class="content-box">
    {{ partial("layout_partials/base_form", ['fields': generalForm, 'id': 'frm_general', 'apply_btn_id': 'saveAct']) }}
    <div style="clear: both; padding: 0 15px 15px;">
        <div id="fc-result" style="display: none;"></div>
        <div id="fc-reboot" class="alert alert-warning" role="alert" style="display: none;">
            {{ lang._('Reboot to finish (Power: Reboot)') }}
        </div>
    </div>
</div>

<div class="content-box" style="margin-top: 15px;">
    <table id="fc-sas" class="table table-condensed table-striped">
        <thead>
            <tr>
                <th>{{ lang._('SA') }}</th>
                <th>{{ lang._('Encryption') }}</th>
                <th>{{ lang._('Authentication') }}</th>
            </tr>
        </thead>
        <tbody></tbody>
    </table>
    <div class="text-muted" style="padding: 0 15px 15px;">
        {{ lang._('On a Sophos XGS the coprocessor encrypts the SAs it has taken, whatever is chosen here; XGS: IPsec says which those are.') }}
    </div>
</div>

<div class="content-box" style="margin-top: 15px;">
    <table id="fc-features" class="table table-condensed table-striped">
        <thead>
            <tr>
                <th>{{ lang._('Processor feature') }}</th>
                <th>{{ lang._('Present') }}</th>
            </tr>
        </thead>
        <tbody></tbody>
    </table>
</div>

{{ partial("OPNsense/FallbackCrypto/credit") }}
