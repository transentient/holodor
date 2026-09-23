# The [pocknix] OTA repo — Holodor's GitHub Releases backend

Holodor devices update with plain `pacman -Syu` against a signed pacman repo of our
packages (kernel, bsp, mesa, gamescope, FEX, steam launcher, …). Reflashing is only
for first install and rescue. This doc covers Holodor's hosting choice; the upstream
pocknix rclone/R2 story is preserved as a fallback code path in `publish-repo.sh`.

## Where it lives

- **Hosting repo:** `github.com/transentient/holodor-releases` — a *separate* repo
  from the source tree, so the OTA channel can go public before the source repo's
  license gate clears. Created 2026-08-18 (PRIVATE until release day).
- **One release tag per SoC:** tag `sm8750` holds the whole sm8750 tree as release
  assets. GitHub's download URL scheme
  `https://github.com/<owner>/<repo>/releases/download/<tag>/<asset>` means
  `POCKNIX_REPO_URL=…/releases/download` + the harness's `<base>/<soc>` join lands
  exactly on the tag — `build-image.sh` needed zero changes.
- **Signing key:** `Holodor Packaging <11418311+transentient@users.noreply.github.com>`,
  ed25519, fpr `BD9D2DF80FD130CFAD441805EF4203C9C3FECC13`, expires 2028-08-17.
  Secret key lives ONLY on fusor (`~cliff/.gnupg`, no passphrase — unattended
  publishes; fusor is a trusted lab box). Public half is COMMITTED at
  `config/pocknix-repo.gpg` and baked + lsigned into every image, so fresh installs
  trust the repo out of the box. **Back the secret key up** (`gpg --export-secret-keys`)
  before release day; losing it means re-keying every shipped image.

## The colon trap (why build/publish/ exists)

GitHub asset names cannot contain `:`, but epoch packages
(`gamescope-1:3.16…`, `mesa-2:26…`) have it in their canonical filenames. If we
uploaded them, GitHub would silently rename and pacman would 404 (the db FILENAME
field wouldn't match any asset). So `publish-repo.sh` stages every package into
`build/publish/<soc>/` with `:` → `_` (hardlinks) and runs `repo-add` **there** —
the published db advertises exactly the sanitized names devices fetch. The
localrepo keeps canonical names (build-image's `file:///localrepo` mount needs them).
Do not "fix" the `_` names; they are load-bearing.

## Publish discipline (breaking these bricks OTA clients)

1. **Never republish the same package filename with different bytes** — bump pkgrel.
   The script enforces this by *skipping* package assets that already exist remotely;
   only `pocknix.db*`, `pocknix.files*` and the pubkey are clobbered per publish.
2. **Packages first, database last** — a client must never see a db entry whose
   package isn't uploaded yet. The script orders uploads accordingly.
3. Signatures are timestamped (nondeterministic), so `.sig`s are only regenerated
   when missing or older than their package — stable bytes, stable client caches.
4. No retry loops, serial uploads, spaced requests (the SourceForge suspension
   lesson, 2026-08-17). If an upload fails, the script dies; rerun by hand.

## Publishing

```sh
DEVICE=sm8750 scripts/publish-repo.sh              # sign + upload (the normal case)
DEVICE=sm8750 scripts/publish-repo.sh --no-upload  # prepare staging only, inspect
DEVICE=sm8750 scripts/publish-repo.sh --serve      # + LAN http :8000 for device tests
```

The image side is automatic: any image built with the (now default)
`POCKNIX_REPO_URL` ships the `[pocknix]` stanza above `[core]` with
`SigLevel = Required DatabaseOptional` and the lsigned pubkey.

## Device-side LAN test (before the repo is public)

While `holodor-releases` is private, devices cannot fetch from GitHub (asset
downloads 404 unauthenticated). Test the full signed chain over LAN instead:

```sh
DEVICE=sm8750 scripts/publish-repo.sh --serve      # on fusor
# on the device (temporary stanza, staging tree, REAL signature verification):
#   [pocknix]
#   SigLevel = Required DatabaseOptional
#   Server = http://192.168.1.70:8000/sm8750
# device must trust the key first (images built after 2026-08-18 already do):
#   pacman-key --add /path/to/pocknix-repo.gpg && pacman-key --lsign-key BD9D2DF8…
pacman -Syy && pacman -Sup                          # sanity: db verifies, upgrades listed
```

## Release-day checklist (flipping public)

1. `gh repo edit transentient/holodor-releases --visibility public`
2. **GPL obligation:** most of what the channel ships is GPL (kernel, etc.). Public
   binaries require a source offer — the source repo (or at minimum the kernel tree +
   PKGBUILDs) must be public/published *at the same time*, per the existing plan to
   release Holodor as a GPL-2.0-or-later Armada/ROCKNIX-credited fork. Blocked on the
   pocknix-os LICENSE question (shuuri-labs/pocknix-os#21).
3. Verify anonymous fetch: `curl -sLo /dev/null -w '%{http_code}\n'
   https://github.com/transentient/holodor-releases/releases/download/sm8750/pocknix.db`
   → must be 200 from a logged-out session.
4. First public image build = default config (stanza already points at the public URL).

## Non-goals for v1 (agreed 2026-08-17)

- No untested kernels in the channel — a kernel goes through an on-device soak before
  publish (add a `-testing` tag/repo later if this gets painful).
- No A/B image updates — far-future; pacman channel only.
- Images do NOT ship via GitHub (2 GiB asset cap) — archive.org (`holodor-odin3`).
