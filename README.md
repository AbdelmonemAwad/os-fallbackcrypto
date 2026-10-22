# Fallback Crypto for OPNsense

IPsec encryption accelerated on the host's processor, for the tunnels a Sophos XGS's coprocessor does not take.

> **Planned - nothing here runs yet.** This repository was opened on 2026-10-22 to hold
> Fallback Crypto as a plugin of its own. No code has been written or moved into it, and there is no
> release.

## What it is to do

- a faster software path for the IPsec associations left to the host;
- a page, in the XGS section of OPNsense's menu or as a plugin of its own - not decided yet.

## Where it fits

It is one part of the [os-xgs-npu](https://github.com/AbdelmonemAwad/os-xgs-npu) project, which puts OPNsense on Sophos XGS hardware, and works the way its other plugins do: changes by pull request, a release installed from **XGS: Updates**, its Arabic in [opnsense-arabic](https://github.com/AbdelmonemAwad/opnsense-arabic)'s catalogue.

## Licence

BSD 2-Clause - see [LICENSE](LICENSE).
