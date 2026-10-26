# Community drafts (2026-09-29) — for Cliff to rewrite in his voice

Two pieces the discoverability review recommended. Both are drafts: plain facts, no promises.
Post them only after editing. Neither belongs in INSTALL.md (steps only).

## 1. Pinned GitHub issue: "Start here"

Title: **Start here: download, install, known issues, where to ask**

> **Download:** the current image and its checksum are at the top of the README and on
> https://holodor.bonesaw.com/ . Every build also has a GitHub Release with the
> checksum attached: https://github.com/transentient/holodor/releases
>
> **Install:** INSTALL.md, top to bottom. Part I writes the SD card, Part II is a one-time
> bootloader step done from Android, Part III is the first boot. Reading Part II before you
> start saves the most grief.
>
> **What works:** Steam Big Picture, desktop mode, controller and paddles, sleep and wake, wifi,
> speakers, SD boot next to Android, optional internal install.
>
> **Known issues (20260927d):**
> - Headphone jack can be silent. Fix in testing; it will arrive as an update, no reflash needed.
> - Unreal Engine 5 games launch but are not playable yet.
>
> **Before you open an issue:** say which build you're on (Settings shows it), whether you boot
> from SD or internal, and what you did right before it went wrong. Logs help; how to grab them
> is in the README.
>
> **Where people talk:** GitHub Issues here, and the AYN Discord's odin3-linux channel. There is
> no Holodor Discord and no plan for one.

## 2. README FAQ (short, after the Download block or near the end)

**Does this wipe Android?** No. From SD, Android is untouched. An internal install shrinks the
Android data partition to make room and keeps Android bootable; the bootloader menu picks which
one starts.

**SD card or internal?** SD is for trying it out and is slower. Internal is the real thing: faster
loading, and games install to the internal storage.

**Why isn't Steam in the image?** Valve's Steam client isn't redistributable, so the image is
"seedless": the first boot downloads Steam itself. That's why first boot needs wifi and a few
minutes.

**Which card writer?** Decompress the .zst first (7-Zip 24.01 or newer, or PeaZip, on Windows),
then Rufus or balenaEtcher. USBImager writes the .img.zst directly without decompressing.

**Do I need to flash the bootloader?** Yes, once, from Android, with the folder that's on the
card after you write it. INSTALL.md Part II. Keep the backup it makes.

**How do I update?** Settings in Steam, or `pacman -Syu` from desktop mode. Updates come from the
project's package repo; you don't reflash for updates.

**What about the Retroid Pocket 5 / other devices?** RP5 support is in progress (it boots as of
2026-09-29). Other Snapdragon handhelds are not supported yet.

## 3. Cloudflare step — DONE 2026-09-29 via API (URL rewrite "/" -> "/index.html" in the http_request_transform ruleset)

holodor.bonesaw.com/ (bare) returns 404 because the bucket doesn't serve index documents. In the
Cloudflare dashboard for bonesaw.com: Rules → Redirect Rules → new rule: if URI Path equals `/`
(hostname holodor.bonesaw.com), redirect to `https://holodor.bonesaw.com/`, 302. Then
the bare domain works as the download page.
