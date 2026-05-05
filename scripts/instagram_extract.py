#!/usr/bin/env python3
"""
Instagram reel/post data extractor.

Usage:
    python3 instagram_extract.py <instagram_url> [--user USERNAME] [--pass PASSWORD]
    python3 instagram_extract.py <instagram_url> --session SESSION_FILE

Session file is saved after first login so subsequent runs don't need credentials.
Output is written to instagram_<shortcode>.json in the current directory.
"""

import argparse
import json
import os
import re
import sys

try:
    import instaloader
except ImportError:
    print("Run: pip3 install instaloader", file=sys.stderr)
    sys.exit(1)


def shortcode_from_url(url: str) -> str:
    m = re.search(r"/(p|reel|tv)/([A-Za-z0-9_-]+)", url)
    if not m:
        raise ValueError(f"Could not extract shortcode from URL: {url}")
    return m.group(2)


def extract(url: str, username: str = "", password: str = "", session_file: str = "") -> dict:
    shortcode = shortcode_from_url(url)
    L = instaloader.Instaloader(
        download_pictures=False,
        download_videos=False,
        download_video_thumbnails=False,
        download_geotags=False,
        download_comments=False,
        save_metadata=False,
        compress_json=False,
    )

    if session_file and os.path.exists(session_file):
        L.load_session_from_file(username or "", session_file)
    elif username and password:
        L.login(username, password)
        if session_file:
            L.save_session_to_file(session_file)
    else:
        print("Warning: no credentials supplied — Instagram will likely return 403.", file=sys.stderr)

    post = instaloader.Post.from_shortcode(L.context, shortcode)

    data = {
        "shortcode": shortcode,
        "url": url,
        "owner_username": post.owner_username,
        "owner_id": post.owner_id,
        "is_video": post.is_video,
        "date_utc": post.date_utc.isoformat(),
        "caption": post.caption,
        "hashtags": list(post.caption_hashtags),
        "mentions": list(post.caption_mentions),
        "likes": post.likes,
        "comments": post.comments,
        "video_url": post.video_url if post.is_video else None,
        "video_view_count": post.video_view_count if post.is_video else None,
        "thumbnail_url": post.url,
        "location": str(post.location) if post.location else None,
        "tagged_users": list(post.tagged_users),
        "accessibility_caption": post.accessibility_caption,
        "media_type": post.typename,
    }

    return data


def main():
    parser = argparse.ArgumentParser(description="Extract Instagram post/reel metadata")
    parser.add_argument("url", help="Instagram reel or post URL")
    parser.add_argument("--user", default=os.environ.get("IG_USERNAME", ""), help="Instagram username (or set IG_USERNAME env var)")
    parser.add_argument("--pass", dest="password", default=os.environ.get("IG_PASSWORD", ""), help="Instagram password (or set IG_PASSWORD env var)")
    parser.add_argument("--session", default=os.environ.get("IG_SESSION_FILE", ""), help="Path to instaloader session file")
    parser.add_argument("--output", default="", help="Output JSON file path (default: instagram_<shortcode>.json)")
    args = parser.parse_args()

    try:
        data = extract(args.url, username=args.user, password=args.password, session_file=args.session)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    out_path = args.output or f"instagram_{data['shortcode']}.json"
    with open(out_path, "w") as f:
        json.dump(data, f, indent=2, default=str)

    print(json.dumps(data, indent=2, default=str))
    print(f"\nSaved to {out_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
