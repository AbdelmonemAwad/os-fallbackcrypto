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
            'none': "{{ lang._('ossl has no fast AES-GCM on this processor') }}"
        };

        function draw(data) {
            const $cards = $('#fc-cards').empty();
            if (!data || data.error) {
                $cards.append(card('bad', 'fa-lock', "{{ lang._('Fallback Crypto') }}", "{{ lang._('The status could not be read.') }}", ''));
                return;
            }
            $cards.append(card(data.ossl_gcm === 'none' ? '' : 'ok', 'fa-microchip', "{{ lang._('Processor') }}",
                data.processor, gcm[data.ossl_gcm]));
            const names = Object.keys(data.providers);
            $cards.append(card(names.length ? 'ok' : 'warn', 'fa-cubes', "{{ lang._('Crypto providers') }}",
                names.length ? names.join(', ') : "{{ lang._('none') }}",
                data.software_only ? "{{ lang._('IPsec held to software providers') }}" : ''));
            const algos = {};
            data.sas.forEach(function (s) { algos[s.enc || '-'] = (algos[s.enc || '-'] || 0) + 1; });
            $cards.append(card('', 'fa-exchange', "{{ lang._('IPsec SAs in the kernel') }}", String(data.sas.length),
                Object.keys(algos).map(function (a) { return a + ' ' + algos[a]; }).join(', ')));
            const pending = (data.mode === 'only') !== !!data.aesni_disabled_now;
            $cards.append(card(pending ? 'warn' : 'ok', 'fa-power-off', "{{ lang._('Next boot') }}",
                data.mode === 'only' ? "{{ lang._('ossl only') }}" : (data.mode === 'alongside' ? "{{ lang._('ossl beside aesni') }}" : "{{ lang._('aesni only') }}"),
                pending ? "{{ lang._('a reboot is needed for the rest') }}" : "{{ lang._('as it runs now') }}"));
            $('#fc-noossl').toggle(!data.ossl_available);

            const $f = $('#fc-features tbody').empty();
            Object.keys(data.features).forEach(function (k) {
                $f.append($('<tr/>').append($('<td/>').append($('<code/>').text(k)))
                    .append($('<td/>').text(data.features[k] ? "{{ lang._('yes') }}" : "{{ lang._('no') }}")));
            });
            const $s = $('#fc-sas tbody').empty();
            data.sas.forEach(function (s) {
                $s.append($('<tr/>').append($('<td/>').append($('<code/>').text(s.pair)))
                    .append($('<td/>').text(s.enc)).append($('<td/>').text(s.auth)));
            });
            if (!data.sas.length) {
                $s.append($('<tr/>').append($('<td colspan="3" class="text-muted"/>').text("{{ lang._('The kernel holds no IPsec SA now.') }}")));
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
            "{{ lang._('IPsec SAs in the kernel') }}", "{{ lang._('Next boot') }}"]);
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
                    $('#fc-result').attr('class', data && data.status === 'ok' ? 'alert alert-success' : 'alert alert-danger')
                        .text(data && data.steps ? data.steps.join(' · ') : '').show();
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
    {{ lang._('This kernel has no ossl module, so only aesni can be used.') }}
</div>

<div class="content-box">
    {{ partial("layout_partials/base_form", ['fields': generalForm, 'id': 'frm_general', 'apply_btn_id': 'saveAct']) }}
    <div style="clear: both; padding: 0 15px 15px;">
        <div id="fc-result" style="display: none;"></div>
        <div id="fc-reboot" class="alert alert-warning" role="alert" style="display: none;">
            {{ lang._('The rest takes effect at the next reboot (Power: Reboot).') }}
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
