---
name: vapi-personal-assistant
description: Set up and manage a personal Vapi.ai voice assistant — a phone number you call to talk to Claude. Use when the user wants to create a voice assistant, configure their Vapi setup, customize the system prompt, check their phone number, or understand costs. Triggers on: "voice assistant", "call Claude", "phone Claude", "Vapi", "talk to Claude", "voice AI", "personal assistant phone".
---

# Personal Claude Voice Assistant (Vapi.ai)

A US phone number you call to talk directly with Claude. Vapi.ai handles the full call pipeline — speech-to-text, Claude, text-to-speech — with no server to run or maintain.

## Use Cases

**Personal productivity**
- **Hands-free thinking partner** — Call while driving, walking, or cooking to think through a problem out loud. Claude responds conversationally, no screen required.
- **Daily briefing** — Call each morning; ask Claude to walk you through your priorities, prep for a meeting, or draft a quick message to send later.
- **Voice journaling** — Dictate notes, ideas, or reflections. Ask Claude to summarize, challenge, or expand on what you said.

**Business**
- **Field sales notes** — Sales reps call after client meetings to verbally log what happened. Custom system prompt routes the output to a structured format ("Summarize what I say as a CRM note with fields: company, contacts, action items").
- **Customer FAQ hotline** — Give clients a phone number backed by a custom-prompted Claude that knows your products, hours, and FAQs. Zero engineering required.
- **After-hours answering** — Small businesses route overflow calls here. Claude answers common questions, takes messages, and explains when a human will follow up.

**Technical / team**
- **On-call triage** — Engineers call Claude while on-site to ask questions about systems, check runbook steps, or think through an incident — without looking at a screen.
- **Meeting prep** — Brief yourself on a client, topic, or competitor by calling two minutes before a meeting starts.

**Accessibility**
- **Phone-first interface** — For users who struggle with typing or prefer voice, this turns Claude into a standard phone call. No app to install, no screen needed.
- **Language practice** — Set the system prompt to respond only in a target language. Speak, listen, repeat.

---

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
3. Preview the setup first (no API calls, no cost):
   ```bash
   python3 ~/.claude/fsp-stack/scripts/vapi_setup.py --dry-run --area-code 415
   ```
4. Provision for real:
   ```bash
   python3 ~/.claude/fsp-stack/scripts/vapi_setup.py --area-code 415
   ```
5. Call the number printed at the end

## CLI Options

| Flag | Default | Description |
|------|---------|-------------|
| `--name` | `Claude` | Display name for the assistant |
| `--area-code` | `415` | 3-digit US area code for your number |
| `--voice-id` | `will` (deep, authoritative) | Vapi native or ElevenLabs voice ID |
| `--model` | `claude-opus-4-7` | Claude model powering the assistant |
| `--max-tokens` | `250` | Max tokens per spoken response |
| `--first-message` | `Hey, this is Claude. What's on your mind?` | Opening line when call connects |
| `--system-prompt` | *(built-in)* | Inline system prompt override |
| `--system-prompt-file` | — | Path to a `.txt` file with the system prompt |
| `--token` | `$VAPI_API_KEY` | Vapi API key |
| `--output` | `~/.claude/vapi-assistant.json` | Where to save state |
| `--dry-run` | — | Preview API payloads without spending anything |
| `--status` | — | Show current assistant config and phone number |
| `--teardown` | — | Delete the assistant and release the phone number |

## Common Commands

```bash
# Check what's running
python3 vapi_setup.py --status

# Preview before spending anything
python3 vapi_setup.py --dry-run --area-code 312

# Provision
python3 vapi_setup.py --area-code 312

# Tear down cleanly (stops billing)
python3 vapi_setup.py --teardown
```

## Customizing the System Prompt

### Inline
```bash
python3 vapi_setup.py --system-prompt "You are a quick, no-nonsense assistant. Answer in one sentence."
```

### From a file
```bash
echo "You are a CRM assistant. Summarize what I say as: Company, Contacts, Action Items." > ~/crm-prompt.txt
python3 vapi_setup.py --system-prompt-file ~/crm-prompt.txt
```

### Edit after provisioning
Go to dashboard.vapi.ai → Assistants → (your assistant) → Edit. Changes take effect immediately, no reprovisioning needed.

## Vapi Built-in Voices

```bash
python3 vapi_setup.py --voice-id will      # default — deep, authoritative
python3 vapi_setup.py --voice-id mark      # warm, conversational
python3 vapi_setup.py --voice-id ryan      # crisp, professional male
python3 vapi_setup.py --voice-id jennifer  # warm, professional female
python3 vapi_setup.py --voice-id sarah     # clear, energetic female
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

## Reprovision / Reset

To swap to a different number or system prompt, tear down first, then reprovision:
```bash
python3 vapi_setup.py --teardown
python3 vapi_setup.py --area-code 212 --voice-id ryan
```

## Troubleshooting

**"Area code unavailable"** — Vapi may not have numbers in that region. Try `--area-code 212` (NYC), `--area-code 312` (Chicago), or `--area-code 512` (Austin).

**ElevenLabs voice not working** — Your ElevenLabs API key must be added in the Vapi dashboard under Keys. The key in `~/.claude/.env` is read by this script only during setup; Vapi needs its own copy at runtime.

**Call quality issues** — Check https://status.vapi.ai for outages. For better transcription in noisy environments, contact Vapi support about the `nova-2-phone` transcriber model.

**Assistant not answering** — Verify the phone number is linked to the assistant: dashboard.vapi.ai → Phone Numbers → (your number) → Assistant.

**Setup failed partway** — The script auto-rolls back if phone provisioning fails after the assistant is created. If rollback also fails, the error message will include the assistant ID to delete manually at dashboard.vapi.ai → Assistants.
