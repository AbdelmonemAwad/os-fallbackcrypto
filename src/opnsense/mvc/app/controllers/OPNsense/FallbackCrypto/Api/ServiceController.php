<?php

/*
 * SPDX-License-Identifier: BSD-2-Clause
 * Copyright (c) 2026 Abdelmonem Awad <eg2@live.com>
 */

namespace OPNsense\FallbackCrypto\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;

class ServiceController extends ApiControllerBase
{
    private function json($action)
    {
        $result = json_decode((new Backend())->configdRun('fallbackcrypto ' . $action), true);
        return is_array($result) ? $result : ['error' => gettext('No answer could be read.')];
    }

    public function statusAction()
    {
        return $this->json('status');
    }

    public function applyAction()
    {
        if (!$this->request->isPost()) {
            return ['status' => 'failed'];
        }
        return $this->json('apply');
    }
}
