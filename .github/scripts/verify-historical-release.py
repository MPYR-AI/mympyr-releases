#!/usr/bin/env python3
"""Verify the public historical compatibility feed without mutating it."""

from __future__ import annotations

import json
import os
import subprocess
import urllib.request
from pathlib import Path
from typing import Any


def api_get(url: str) -> Any:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}",
            "X-GitHub-Api-Version": "2026-03-10",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def main() -> int:
    baseline = json.loads(
        Path(".github/historical-release-baseline.json").read_text(encoding="utf-8")
    )
    failures: list[str] = []
    actual_tags = subprocess.check_output(
        ["git", "tag", "--list", "v*", "--sort=version:refname"],
        text=True,
    ).splitlines()
    if actual_tags != baseline["tags"]:
        failures.append("historical tag set drifted")
    for tag in baseline["tags"]:
        commit = subprocess.check_output(
            ["git", "rev-list", "-n", "1", tag],
            text=True,
        ).strip()
        if commit != baseline["commit"]:
            failures.append(f"{tag} moved to an unexpected commit")

    releases = api_get(
        "https://api.github.com/repos/MPYR-AI/mympyr-releases/releases?per_page=100"
    )
    if len(releases) != baseline["release_count"]:
        failures.append("historical release count drifted")
    if sorted(release["tag_name"] for release in releases) != sorted(baseline["tags"]):
        failures.append("historical release tag set drifted")
    if any(release["draft"] or release["prerelease"] for release in releases):
        failures.append("historical feed contains a draft or prerelease")

    assets = [asset for release in releases for asset in release["assets"]]
    if len(assets) != baseline["asset_count"]:
        failures.append("historical asset count drifted")
    if sum(asset["size"] for asset in assets) != baseline["asset_bytes"]:
        failures.append("historical asset byte total drifted")
    if any(not str(asset.get("digest", "")).startswith("sha256:") for asset in assets):
        failures.append("historical asset is missing a SHA-256 digest")
    actual_assets = sorted(
        (
            {
                "tag": release["tag_name"],
                "name": asset["name"],
                "size": asset["size"],
                "digest": asset.get("digest"),
            }
            for release in releases
            for asset in release["assets"]
        ),
        key=lambda asset: (asset["tag"], asset["name"]),
    )
    if actual_assets != baseline["assets"]:
        failures.append("historical per-asset identity ledger drifted")

    if failures:
        print("\n".join(failures))
        return 1
    print(
        "Historical feed PASS: "
        f"{len(releases)} releases, {len(assets)} assets, "
        f"{sum(asset['size'] for asset in assets)} bytes."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
