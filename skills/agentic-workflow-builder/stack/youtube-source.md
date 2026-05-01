# YouTube source integration

Two separable concerns: **listing new videos on a channel** and **fetching a transcript for a given video**. Pick per use case — you often only need one.

## Listing new videos

The cleanest path is YouTube Data API v3 (`search.list` or `playlistItems.list` on the channel's uploads playlist). `playlistItems` is more reliable since `search.list` has stricter quota and ordering oddities.

```ts
// src/lib/youtube.ts
const API = "https://www.googleapis.com/youtube/v3";

export async function listChannelUploads(channelId: string, maxResults = 20) {
  // 1. channel → uploads playlist ID
  const chRes = await fetch(
    `${API}/channels?part=contentDetails&id=${channelId}&key=${process.env.YOUTUBE_API_KEY}`
  );
  const chData = await chRes.json();
  const uploadsId = chData.items?.[0]?.contentDetails?.relatedPlaylists?.uploads;
  if (!uploadsId) throw new Error(`channel ${channelId} has no uploads playlist`);

  // 2. playlistItems.list
  const plRes = await fetch(
    `${API}/playlistItems?part=snippet&playlistId=${uploadsId}&maxResults=${maxResults}&key=${process.env.YOUTUBE_API_KEY}`
  );
  const { items } = await plRes.json();
  return items.map((i: any) => ({
    id: i.snippet.resourceId.videoId,
    title: i.snippet.title,
    publishedAt: i.snippet.publishedAt,
    url: `https://youtu.be/${i.snippet.resourceId.videoId}`,
  }));
}
```

**Alternative**: RSS. Every YouTube channel has `https://www.youtube.com/feeds/videos.xml?channel_id=<id>`. No API key, no quota, but capped at ~15 most recent videos and no video metadata beyond title/published/url. Good enough for most pollers.

## Fetching a transcript

YouTube's caption API is locked down. Practical options:

1. **`youtube-transcript-api` (Python)** — reliable for public videos with auto-captions. Shell out from Node or run a thin Python sidecar:
   ```bash
   python3 -c "from youtube_transcript_api import YouTubeTranscriptApi; api=YouTubeTranscriptApi(); print(' '.join([s.text for s in api.fetch('<videoId>', languages=['en'])]))"
   ```
2. **yt-dlp `--write-auto-sub`** — works sometimes, but YouTube increasingly requires a PO token. Fragile.
3. **Third-party services** (Tactiq, youtubetranscript.com, etc.) — rate-limited, anti-bot. Avoid for automation.
4. **Run audio through Whisper/Deepgram** — download audio with yt-dlp, transcribe. Most robust but slowest and costs compute.

For anything on a schedule, prefer option 1 wrapped in a trigger.dev task with `retry.maxAttempts: 3` — the Python API occasionally rate-limits.

## Idempotency key

Always `youtube-video:<videoId>`. Video IDs are stable and globally unique.
