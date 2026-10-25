# Fallback Crypto for OPNsense

IPsec encryption accelerated on the host's processor, for the tunnels a Sophos XGS's coprocessor does not take.

> ~~**Planned - nothing here runs yet.** This repository was opened on 2026-10-22 to hold
> Fallback Crypto as a plugin of its own. No code has been written or moved into it, and there is no
> release.~~
>
> ~~**Written, not released (2026-10-22): the first part.** The choice of the kernel's crypto provider
> for IPsec. There is no release, it has not been installed on an appliance, and nothing has been
> measured through a tunnel yet. What was run is listed under [What is tested](#what-is-tested).~~
>
> **1.0.0, the first release (2026-10-25): the first part**, the choice of the kernel's crypto
> provider for IPsec. Installed and its page opened on an XGS 3300 (OPNsense 26.7.7) before the
> release; no provider has been applied through it and nothing measured through a tunnel yet. Updated
> from XGS: Updates when os-xgs-npu is installed, or by its own self-update - see [Updates](#updates).

## What it does

**VPN: IPsec: Fallback Crypto** (XGS: Fallback Crypto when os-xgs-npu is installed) chooses which
of the kernel's crypto drivers encrypts the IPsec tunnels the host carries itself:

- **aesni only** - what OPNsense ships: `aesni(4)` is built into its kernel;
- **ossl beside aesni** - `ossl(4)`, the kernel's OpenSSL-based driver, loaded now and early in every
  boot, before any tunnel exists. The kernel gives a new session to the provider with the best probe
  value, and both answer "accelerated software", so on the tie it takes the one with fewer sessions:
  new SAs are shared between the two (`crypto_select_driver()`, opnsense/src stable/26.7);
- **ossl only** - the same, and `aesni` switched off at the loader (`hint.aesni.0.disabled=1`,
  written through OPNsense's own Tunables, so it is visible in System: Settings: Tunables), so from
  the next boot every session is ossl's.

The page shows the host's processor and the features AES-GCM depends on, which AES-GCM code ossl
takes there, the providers present, whether IPsec is held to software providers, and the SAs in the
kernel with their algorithms.

**Why ossl.** It carries OpenSSL's own AES-GCM: with AVX-512 and VAES the wide code, and with AVX,
PCLMULQDQ and MOVBE the stitched AES-NI/GHASH code (`ossl_x86.c`), which processes several blocks at
once. The XGS 3300's host, an AMD Ryzen Embedded V1780B, has AVX, PCLMULQDQ and MOVBE and no AVX-512,
so ossl would take the second.

~~a faster software path for the IPsec associations left to the host~~ - written as the choice of
provider above; whether ossl is faster than aesni on these hosts, and by how much, is not measured yet.
No new crypto driver was needed for this step: OpenSSL's code is already in the kernel as ossl.

~~a page, in the XGS section of OPNsense's menu or as a plugin of its own - not decided yet~~ - a
plugin of its own, under **VPN: IPsec** (under **XGS** when os-xgs-npu is installed): it is not for
XGS appliances only.

## Beside os-xgs-npu

On the XGS 136, os-xgs-npu holds IPsec's sessions to software providers
(`net.inet.ipsec.crypto_support`, its issue 399: the host's AMD ccp(4) failed every AES-GCM
operation). ossl is a software provider, so the two agree; this plugin's early hook (05) runs before
os-xgs-npu's (07). On any XGS the coprocessor encrypts the SAs it has taken whatever is chosen here;
this changes only the ones left to the host.

## What is tested

On the second XGS 3300, 2026-10-22, from a copy in `/tmp`, nothing installed and nothing loaded:

- every PHP file passes `php -l`; both Volt templates compile; the early hook passes `sh -n`;
- `status.py`: AMD Ryzen Embedded V1780B, AES-NI, PCLMULQDQ, AVX, MOVBE, AVX2 and SHA present, no
  AVX-512 or VAES, so ossl's AES-GCM would be the AVX path; `/boot/kernel/ossl.ko` present and not
  loaded; aesni the only provider; two SAs in the kernel, both `aes-gcm-16`.

On the first XGS 3300, 2026-10-25, OPNsense 26.7.7 with os-xgs-npu installed, before the release:

- installed by `install/install.sh`: rc 0, its PHP passing `php -l` in the installer;
- the page opened in the browser, its summary cards reading the status;
- its menu place: under **XGS** with os-xgs-npu installed; in its own section, **VPN: IPsec**, when
  os-xgs-npu's menu file was set aside, and back under XGS when it was put back (`place-menu.sh`).

Not tested: `apply.php` (it loads ossl and writes the tunable), a tunnel on ossl, the throughput of
either provider, aesni switched off, ~~the page in a browser~~ (opened on 2026-10-25, above), the
package (built by `tools/make-package.sh`, added with pkg), and an install on a plain OPNsense,
without os-xgs-npu.

## Installation

It is not in the OPNsense plugin repository, so there is no `pkg install os-fallbackcrypto`.

**From a checkout** of this repository, on the firewall, as root:

```sh
sh install/install.sh
```

It copies `src/` onto `/usr/local` (the early boot hook with it), checks the PHP with `php -l` and
the Python with `py_compile`, puts the page in the menu (`place-menu.sh`: XGS with os-xgs-npu,
VPN: IPsec without) and records the commit for the self-update. Safe to run again: the settings in
config.xml are kept. Nothing changes until a provider is chosen and applied. Before
`sh install/uninstall.sh`, set it back to "aesni only" and apply, or remove `hint.aesni.0.disabled`
from System: Settings: Tunables afterwards.

**From a release's package.** A release carries `os-fallbackcrypto-<version>.pkg` and `SHA256SUMS`,
built by `tools/make-package.sh` in the release workflow; installing it has not been tested yet.
Check it and read it before adding it, as root:

```sh
sha256sum -c SHA256SUMS
pkg info -lF os-fallbackcrypto-1.0.0.pkg      # every file it will write
pkg add os-fallbackcrypto-1.0.0.pkg
```

`pkg delete os-fallbackcrypto` leaves ossl loaded until the next boot, which no longer loads it, and
keeps the settings and a `hint.aesni.0.disabled` row in Tunables if one was written - it says so
when it does. The same package is built on the firewall from a checkout with
`sh tools/make-package.sh -o /tmp`.

## Updates

Taken by hand, to this repository's **releases**: from **XGS: Updates**, its *Plugins* tab, where an
[os-xgs-npu](https://github.com/AbdelmonemAwad/os-xgs-npu) that lists this plugin is installed - the
tab calls `/usr/local/opnsense/scripts/fallbackcrypto/self-update.py`, with `check` to ask and
without it to install - or by running that script. No cron entry runs it. It asks GitHub for the
latest release and, when that is ahead of what is installed, downloads it and runs the
`install/install.sh` it carries - the same script a hand install runs. A change merged on `main`
reaches an installed firewall when it is released, not before.

- **Only forward.** What is installed is recorded in `/usr/local/share/os-fallbackcrypto/installed.json`
  by the installer: the commit, from a git checkout or from the `.source-commit` stamp an update
  leaves in the tree. A firewall running something newer than the release is not taken back; an
  install with no commit recorded takes the latest release once.
- **A package install records no commit**, so its first self-update takes the latest release and
  installs it with `install/install.sh`, outside pkg. A package is updated with a newer package
  instead: `pkg add -f`.
- **What happened** is in the system log as `self-update`, in
  `/usr/local/share/os-fallbackcrypto/update.json`, and the installer's output in `update.log`
  beside it.
- `self-update.py check` says what it would do and changes nothing.

Not tested yet: an update taken this way - 1.0.0 is the first release, so none has been ahead of an
installed copy.

## Where it fits

It is one part of the [os-xgs-npu](https://github.com/AbdelmonemAwad/os-xgs-npu) project, which puts OPNsense on Sophos XGS hardware, and works the way its other plugins do: changes by pull request, a release installed from **XGS: Updates** (once it is listed there), its Arabic in [opnsense-arabic](https://github.com/AbdelmonemAwad/opnsense-arabic)'s catalogue.

## Licence

BSD 2-Clause - see [LICENSE](LICENSE).
