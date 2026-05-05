#!/usr/bin/env python3
"""
Instagram reel/post data extractor.

Requires an Apify API token (free tier works):
  1. Sign up at https://apify.com (free)
  2. Copy your token from https://console.apify.com/account/integrations
  3. Set it: export APIFY_API_TOKEN=your_token
     or pass --token your_token

Usage:
    python3 instagram_extract.py <instagram_url> [--token TOKEN] [--output FILE]

Output: JSON file at instagram_<shortcode>.json (or --output path)
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.request
import urllib.parse
import ssl

APIFY_ACTOR = "apify/instagram-scraper"
POLL_INTERVAL = 3   # seconds between status checks
TIMEOUT = 120       # max seconds to wait for Apify run


def shortcode_from_url(url: str) -> str:
    m = re.search(r"/(p|reel|tv)/([A-Za-z0-9_-]+)", url)
    if not m:
        raise ValueError(f"Could not extract shortcode from URL: {url}")
    return m.group(2)


def _api_call(method: str, path: str, body: dict = None, token: str = "") -> dict:
    """Minimal Apify API client using stdlib only."""
    base = "https://api.apify.com/v2"
    url = f"{base}{path}"
    if token:
        sep = "&" if "?" in url else "?"
        url = f"{url}{sep}token={token}"

    data = json.dumps(body).encode() if body else None
    headers = {"Content-Type": "application/json", "Accept": "application/json"}
    req = urllib.request.Request(url, data=data, headers=headers, method=method)

    ctx = ssl.create_default_context()
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=30) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"Apify API {method} {path} → {e.code}: {e.read().decode()[:300]}")


def extract_via_apify(url: str, token: str) -> dict:
    shortcode = shortcode_from_url(url)
    print(f"Starting Apify run for shortcode: {shortcode}", file=sys.stderr)

    # Start actor run
    run = _api_call(
        "POST",
        f"/acts/{APIFY_ACTOR}/runs",
        body={
            "directUrls": [f"https://www.instagram.com/reel/{shortcode}/"],
            "resultsType": "posts",
            "resultsLimit": 1,
        },
        token=token,
    )
    run_id = run["data"]["id"]
    dataset_id = run["data"]["defaultDatasetId"]
    print(f"Run started: {run_id}", file=sys.stderr)

    # Poll until finished
    deadline = time.time() + TIMEOUT
    while time.time() < deadline:
        time.sleep(POLL_INTERVAL)
        status_resp = _api_call("GET", f"/actor-runs/{run_id}", token=token)
        status = status_resp["data"]["status"]
        print(f"  status: {status}", file=sys.stderr)
        if status == "SUCCEEDED":
            break
        if status in ("FAILED", "ABORTED", "TIMED-OUT"):
            raise RuntimeError(f"Apify run {status}: {run_id}")

    # Fetch results
    items_resp = _api_call("GET", f"/datasets/{dataset_id}/items?limit=1", token=token)
    items = items_resp.get("items", [])
    if not items:
        raise RuntimeError("Apify run succeeded but returned no items.")

    raw = items[0]

    # Normalise to a clean schema
    data = {
        "shortcode": shortcode,
        "url": url,
        "owner_username": raw.get("ownerUsername") or raw.get("owner", {}).get("username"),
        "owner_full_name": raw.get("ownerFullName") or raw.get("owner", {}).get("fullName"),
        "is_video": raw.get("isVideo", True),
        "date_utc": raw.get("timestamp"),
        "caption": raw.get("caption"),
        "hashtags": raw.get("hashtags", []),
        "mentions": raw.get("mentions", []),
        "likes": raw.get("likesCount") or raw.get("likes"),
        "comments": raw.get("commentsCount") or raw.get("comments"),
        "video_url": raw.get("videoUrl"),
        "video_view_count": raw.get("videoViewCount") or raw.get("videoPlayCount"),
        "thumbnail_url": raw.get("displayUrl") or raw.get("thumbnailUrl"),
        "audio_track": raw.get("musicInfo", {}).get("song_name") if raw.get("musicInfo") else None,
        "location": raw.get("locationName"),
        "tagged_users": [u.get("username") for u in raw.get("taggedUsers", [])],
        "media_type": raw.get("type") or raw.get("productType"),
        "raw": raw,
    }
    return data


def main():
    parser = argparse.ArgumentParser(description="Extract Instagram post/reel metadata via Apify")
    parser.add_argument("url", help="Instagram reel or post URL")
    parser.add_argument("--token", default=os.environ.get("APIFY_API_TOKEN", ""),
                        help="Apify API token (or set APIFY_API_TOKEN env var)")
    parser.add_argument("--output", default="", help="Output JSON file path")
    args = parser.parse_args()

    if not args.token:
        print(
            "Error: Apify API token required.\n"
            "  Sign up free at https://apify.com\n"
            "  Then: export APIFY_API_TOKEN=your_token",
            file=sys.stderr,
        )
        sys.exit(1)

    try:
        data = extract_via_apify(args.url, args.token)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    out_path = args.output or f"instagram_{data['shortcode']}.json"
    with open(out_path, "w") as f:
        json.dump(data, f, indent=2, default=str)

    # Print clean summary (excluding raw blob)
    summary = {k: v for k, v in data.items() if k != "raw"}
    print(json.dumps(summary, indent=2, default=str))
    print(f"\nFull data saved to {out_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
