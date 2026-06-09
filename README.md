# mympyr-releases

Public **update feed** for **myMPYR.app** — consumed by [electron-updater](https://www.electron.build/auto-update).

This repo holds release **binaries** only (`.dmg`, `.zip`, `.blockmap`, `latest-mac.yml`). It contains **no application source code**. The source lives in the private `mympyr-desktop` repo.

Why a separate public repo: a public feed lets installed copies of myMPYR.app auto-update tokenlessly off GitHub's CDN — no credential is ever embedded in the shipped binary. See `ADR-049-update-feed-host` (mpyr-plans). Endgame: migrate to Cloudflare R2 behind `updates.mpyr.ai`.

Releases are published by `electron-builder` at build time. Do not commit here by hand.

© 2026 MPYR Strategic LLC, doing business as MPYR AI.
