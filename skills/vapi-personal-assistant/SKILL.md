---
name: vapi-personal-assistant
description: Set up and manage a personal Vapi.ai voice assistant — a phone number you call to talk to Claude. Use when the user wants to create a voice assistant, configure their Vapi setup, customize the system prompt, check their phone number, or understand costs. Triggers on: "voice assistant", "call Claude", "phone Claude", "Vapi", "talk to Claude", "voice AI", "personal assistant phone".
---

# Personal Claude Voice Assistant (Vapi.ai)

A US phone number you call to talk directly with Claude. Vapi.ai handles the full call pipeline — speech-to-text, Claude, text-to-speech — with no server to run or maintain.

## Prerequisites

- Vapi.ai account — free at https://vapi.ai
- `VAPI_API_KEY` in `~/.claude/.env`
- (Optional) `ELEVENLABS_VOICE_ID` for a custom voice

## Setup

1. Get your Vapi API key: dashboard.vapi.ai → API Keys
2. Add to `~/.claude/.env`:
   ```
   VAPI_API_KEY=your_key_here
   ```
3. Run the setup script:
   ```bash
   python3 ~/.claude/fsp-stack/scripts/vapi_setup.py --area-code 415
   ```
4. Note the phone number printed at the end and call it

## CLI Options

| Flag | Default | Description |
|------|---------|-------------|
| `--name` | `Claude` | Display name for the assistant |
| `--area-code` | `415` | 3-digit US area code for your number |
| `--voice-id` | `will` (deep, authoritative) | ElevenLabs or Vapi voice ID |
| `--system-prompt` | *(built-in)* | Override the default system prompt |
| `--token` | `$VAPI_API_KEY` | Vapi API key |
| `--output` | `~/.claude/vapi-assistant.json` | Where to save state |
| `--dry-run` | — | Preview API payloads without spending anything |

Always preview first:
```bash
python3 vapi_setup.py --dry-run --area-code 415
```

## Customizing the System Prompt

Pass `--system-prompt "..."` to replace the default, or edit the assistant in the Vapi dashboard after setup (dashboard.vapi.ai → Assistants).

Example — make Claude more terse:
```bash
python3 vapi_setup.py --system-prompt "You are a quick, no-nonsense assistant. Answer in one sentence."
```

## Vapi Built-in Voices

Change the voice with `--voice-id`:

```bash
python3 vapi_setup.py --voice-id will    # default — deep, authoritative
python3 vapi_setup.py --voice-id mark    # warm, conversational
python3 vapi_setup.py --voice-id ryan    # crisp, professional male
python3 vapi_setup.py --voice-id jennifer  # warm, professional female
python3 vapi_setup.py --voice-id sarah   # clear, energetic female
```

No extra accounts or keys needed for Vapi built-in voices.

## Custom Voice (ElevenLabs)

1. Find a voice ID at https://elevenlabs.io/voice-library
2. Add to `~/.claude/.env`:
   ```
   ELEVENLABS_VOICE_ID=your_voice_id
   ```
3. Configure your ElevenLabs API key in the Vapi dashboard → Keys
4. Rerun the setup script (a new assistant + number will be created)

## Cost

| Component | Rate |
|-----------|------|
| Vapi platform | ~$0.05/min |
| Claude claude-opus-4-7 | ~$0.15–0.20/min |
| Voice (ElevenLabs) | ~$0.05–0.10/min |
| Voice (Vapi native) | included |
| Phone number | ~$2/month flat |
| **Total** | **~$0.25–0.33/min** |

## Check Your Setup

```bash
cat ~/.claude/vapi-assistant.json
```

## Reprovision

Delete the state file and rerun to get a new assistant and number:
```bash
rm ~/.claude/vapi-assistant.json
python3 vapi_setup.py --area-code 212
```

**Cancel the old number** in the Vapi dashboard first to stop billing (dashboard.vapi.ai → Phone Numbers).

## Troubleshooting

**"Area code unavailable"** — Vapi may not have numbers in that region. Try `--area-code 212` (NYC), `--area-code 312` (Chicago), or `--area-code 512` (Austin).

**ElevenLabs voice not working** — Confirm your ElevenLabs API key is added in the Vapi dashboard under Keys. The key in `~/.claude/.env` is not enough; Vapi needs its own copy.

**Call quality issues** — Check https://status.vapi.ai for outages. For better transcription in noisy environments, contact Vapi support about the `nova-2-phone` transcriber model.

**Assistant not answering** — Verify the phone number is linked to the assistant in dashboard.vapi.ai → Phone Numbers → (your number) → Assistant.
