# Steam firstboot bootstrap (seedless images) — design

Status: agreed with Cliff 2026-08-16 (distribution-pivot session); this doc is the
implementation reference. Goal: the PUBLIC Holodor image ships WITHOUT Valve's Steam
client (no redistribution exposure) and downloads it on first boot instead.

## The problem

Today the client is baked into `/home/deck` at image build time (`bootstrap_steam_seed`
in build-image.sh) and `pocknix-steam` hard-fails if it's missing. A seedless image
therefore needs: a way to get Wi-Fi credentials onto the device *before* any Steam UI
exists, an on-device downloader that is honest about what it's doing and safe against
every failure mode, and a build switch that omits the seed.

## Non-negotiables (agreed)

1. **A failed or interrupted download can NEVER brick the device.** Everything the
   bootstrap writes lives under `/home/deck`. The OS boots and the session supervisor
   retries regardless of what happened to a previous attempt.
2. **No hard-coded versioned URLs.** Runtime version comes from
   `latest-public-beta.txt`; the client zip name comes from Valve's channel manifest at
   run time. (The alias path 403s plain GETs — the July lesson; only the resolved
   versioned paths are fetched.)
3. **Everything downloaded is hash-verified before use** (see "Verification").
4. **Resumable**: `curl -C -` with retry/backoff; an interrupted boot resumes the
   partial download on the next attempt instead of starting over.
5. **Atomic**: the client tree is assembled in a staging dir and only `mv`'d to
   `~/.local/share/Steam` once complete and verified. The launcher's existing
   "client present" check (`-x .../steamrtarm64/steam`) therefore only ever sees
   absent or complete — never half.
6. **Honest offline screen**: if there's no network, the panel says so and explains
   the `wifi.txt` mechanism. No fake progress, no silent shell drop.
7. **The bootstrap ships as a package** (`pocknix-steam`) so the OTA channel can fix
   it after release.

## Wi-Fi without a keyboard: `wifi.txt`

The FAT boot partition (`/flash`, partition 1 — visible on any PC that flashed the
card) accepts a `wifi.txt`:

```
ssid=MyNetwork
password=hunter2
country=US        # optional; without it 5 GHz won't associate (world regdom)
```

`pocknix-wifi-import.service` (root oneshot, every boot, gated on
`ConditionPathExists=/flash/wifi.txt`) imports it using the proven dual-write recipe
from build-sd-image.sh's dev preseed: a NetworkManager keyfile (so Steam's UI sees the
connection) **plus** the iwd `KnownNetwork` `.psk` (NM 1.56's iwd backend doesn't hand
keyfile PSKs to iwd — without the direct credential, association dead-ends at
need-auth). After a successful import the file is renamed to `wifi.txt.imported` so
the plaintext PSK isn't re-parsed forever and the user can see it was taken. Parse
errors are written to `/flash/wifi-import-error.txt`. Runs before/independent of the
session, so dropping a corrected `wifi.txt` and rebooting always works.

Limitation (documented, accepted): SSIDs needing iwd's hex-encoded filename form
(spaces/non-alphanumerics) get only the NM keyfile in v1; iwd hex-encoding is a
follow-up. [IMPL NOTE: shipped v1 hex-encodes too — limitation retired.]

## The bootstrap: `pocknix-steam-bootstrap`

Runs as `deck`. Invoked by `pocknix-steam` (game session) when the client tree is
missing; the desktop `steam` wrapper calls it too (replacing its stale
`pocknix-steam-install` fallback). flock-singleton so the two entry points can't race.

UI: writes a plain-text status screen directly to `/dev/tty1` (the deck session owns
it; the supervisor already blanks it between compositors). Stages, sizes, and errors
are spelled out. Total download is ~350 MB (52 MB runtime + 110 MB client zip + the
client's own self-update packages).

Steps:

1. **Done check**: complete tree already at `~/.local/share/Steam` → exit 0.
2. **Network wait**: poll DNS for `repo.steampowered.com`. After ~60 s show the
   offline screen (wifi.txt instructions) and keep polling forever — there is nothing
   better to do, and the wifi importer may bring the network up at any time after the
   user acts.
3. **Download** (into `~/.local/state/pocknix-steam-bootstrap/`, same filesystem):
   - runtime: resolve version from `latest-public-beta.txt`, fetch that version's
     `SHA256SUMS`, then `steam-runtime-steamrt-arm64.tar.xz` (resumable).
   - client: fetch `steam_client_steamdeck_stable_linuxarm64` (binary VDF), extract
     the plain `bins_linuxarm64_linuxarm64.zip.<sha1>` name (not the `.vz.` variant),
     download it (resumable).
   Retry policy: `curl --retry` with backoff; single spaced attempts, no tight loops
   (the SourceForge lesson). A verification failure deletes the artifact and re-downloads
   once; two failures = clear error + exit (supervisor retries next launch).
4. **Verify**:
   - runtime tar: sha256 against the version's `SHA256SUMS` entry (verified present).
   - client zip: sha1 against its own filename suffix (verified 2026-08-17: the suffix
     IS the file's sha1).
5. **Assemble in staging** (`~/.local/share/Steam.staging`, wiped at start if left
   over): untar runtime, unzip client, relative libibus symlink, `package/beta` =
   `steamdeck_stable` — exactly the layout `pocknix-steam-install` builds at bake time.
6. **Finalize under Xvfb**: run the client updater headlessly
   (`xvfb-run steam -steamdeck -exitsteam`, the proven bake flow) so it self-updates
   and writes the channel `.installed` manifest. Without the manifest Steam re-installs
   on first launch; with root-owned files it loops — here everything is deck-owned by
   construction. Requires network (it downloads the update packages); we're online by
   this point. On internal UFS this is minutes.
7. **Strip + atomic move**: remove per-session cruft and `registry.vdf` (same list as
   the bake — so the real Steam OOBE still runs), verify `steamui.so` + `.installed`,
   then `mv Steam.staging Steam` and create the relative `~/.steam` symlinks.
8. Exit 0 → `pocknix-steam` proceeds into gamescope → Steam Deck OOBE (Wi-Fi already
   up, language pick, sign-in) — stock SteamOS feel.

Failure at any step: honest message on tty1 (+ full log at
`~/.local/state/pocknix-steam-bootstrap/bootstrap.log`), exit non-zero. The session
supervisor's loop relaunches `pocknix-steam` → bootstrap retries, resuming downloads.
(The supervisor's 3×-fast-fail shell drop isn't tripped: bootstrap attempts take >5 s.)

## Build-system switch

- `HOLODOR_SEEDLESS=1` on `build-image.sh` skips `bootstrap_steam_seed` entirely (no
  bake, no pre-extract). Passed through to `build-sd-image.sh`, whose "Steam client
  not pre-extracted" die-guard becomes conditional.
- Dev images keep the seed by default (fast iteration, no per-boot downloading);
  the PUBLIC release builds with `HOLODOR_SEEDLESS=1` + `HOLODOR_RELEASE=1`.
- `pocknix-steam`'s network deps (curl/wget/unzip/tar/xvfb) were already rootfs
  residents for the bake; they are genuine runtime deps again — comment updated.

## What this deliberately does not do (v1)

- No progress bar for the Xvfb finalize step (stage message + spinner only; the
  updater's own output goes to the log).
- No re-bootstrap/repair UI. Deleting `~/.local/share/Steam` and relaunching IS the
  repair path.
- No mirror/fallback CDN. Valve's CDN with resume+retry is the single source, as on
  real SteamOS.
