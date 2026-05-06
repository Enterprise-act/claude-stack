#!/usr/bin/env python3
"""
Personal Claude voice assistant setup via Vapi.ai.

Creates a Vapi assistant backed by Claude and provisions a US phone number.
Call that number to speak directly with Claude — no server required.

Requires a Vapi API key (free to sign up):
  1. Sign up at https://vapi.ai
  2. Copy your key from dashboard.vapi.ai → API Keys
  3. Set it: export VAPI_API_KEY=your_key
     or pass --token your_key

Usage:
    python3 vapi_setup.py [--name NAME] [--area-code CODE] [--dry-run]
    python3 vapi_setup.py --token YOUR_KEY --area-code 415

Output: assistant details + phone number printed to stdout;
        state saved to ~/.claude/vapi-assistant.json
"""

import argparse
import datetime
import json
import os
import sys
import urllib.error
import urllib.request
import ssl

VAPI_BASE = "https://api.vapi.ai"
DEFAULT_VOICE_PROVIDER = "vapi"
DEFAULT_VOICE_ID = "will"
STATE_FILE = os.path.expanduser("~/.claude/vapi-assistant.json")

DEFAULT_SYSTEM_PROMPT = """\
You are Claude, a personal AI assistant accessible by phone call.

- Keep responses concise and conversational — 2-3 sentences max
- Never use bullet points, markdown, or formatted lists — plain spoken language only
- If you don't know something, say so briefly and offer an alternative
- Tone: warm, direct, intelligent, slightly informal

Constraints:
- Frame medical, legal, or financial topics as "one angle to consider"
- For real-time data (live scores, stock prices), acknowledge the limit and suggest a source\
"""


def _api_call(method: str, path: str, body: dict = None, token: str = "") -> dict:
    """Minimal Vapi API client using stdlib only."""
    url = f"{VAPI_BASE}{path}"
    data = json.dumps(body).encode() if body else None
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": f"Bearer {token}",
    }
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    ctx = ssl.create_default_context()
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=30) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"Vapi API {method} {path} → {e.code}: {e.read().decode()[:300]}")


def create_assistant(name: str, system_prompt: str, voice_provider: str, voice_id: str, token: str) -> dict:
    print(f"Creating assistant '{name}'...", file=sys.stderr)
    payload = {
        "name": name,
        "model": {
            "provider": "anthropic",
            "model": "claude-opus-4-7",
            "systemPrompt": system_prompt,
            "temperature": 0.7,
            "maxTokens": 250,
        },
        "voice": {
            "provider": voice_provider,
            "voiceId": voice_id,
        },
        "firstMessage": "Hey, this is Claude. What's on your mind?",
        "endCallFunctionEnabled": True,
        "endCallMessage": "Goodbye! Call back anytime.",
        "transcriber": {
            "provider": "deepgram",
            "model": "nova-2",
            "language": "en-US",
        },
        "silenceTimeoutSeconds": 30,
    }
    return _api_call("POST", "/assistant", body=payload, token=token)


def provision_phone_number(area_code: str, assistant_id: str, token: str) -> dict:
    print(f"Provisioning phone number (area code {area_code})...", file=sys.stderr)
    payload = {
        "provider": "vapi",
        "areaCode": area_code,
        "assistantId": assistant_id,
    }
    try:
        return _api_call("POST", "/phone-number", body=payload, token=token)
    except RuntimeError as e:
        if "404" in str(e) or "400" in str(e) or "unavailable" in str(e).lower():
            print(
                f"\nArea code {area_code} is unavailable — try a different one:\n"
                "  python3 vapi_setup.py --area-code 212   (New York)\n"
                "  python3 vapi_setup.py --area-code 312   (Chicago)\n"
                "  python3 vapi_setup.py --area-code 512   (Austin)\n",
                file=sys.stderr,
            )
        raise


def save_state(data: dict, path: str) -> str:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # Refuse to follow symlinks for security
    if os.path.islink(path):
        raise RuntimeError(f"State file path {path} is a symlink — aborting.")
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
    os.chmod(path, 0o600)
    return path


def main():
    parser = argparse.ArgumentParser(description="Set up a personal Claude voice assistant via Vapi.ai")
    parser.add_argument("--name", default="Claude", help="Display name for the assistant (default: Claude)")
    parser.add_argument("--area-code", default="415", help="3-digit US area code for the phone number (default: 415)")
    parser.add_argument("--voice-id", default="", help="ElevenLabs or Vapi voice ID to use")
    parser.add_argument("--system-prompt", default="", help="Custom system prompt (overrides default)")
    parser.add_argument("--token", default=os.environ.get("VAPI_API_KEY", ""),
                        help="Vapi API key (or set VAPI_API_KEY env var)")
    parser.add_argument("--output", default=STATE_FILE,
                        help=f"Path to save state JSON (default: {STATE_FILE})")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print API payloads without making any calls")
    args = parser.parse_args()

    if not args.token and not args.dry_run:
        print(
            "Error: Vapi API key required.\n"
            "  Sign up free at https://vapi.ai\n"
            "  Then: export VAPI_API_KEY=your_key",
            file=sys.stderr,
        )
        sys.exit(1)

    token = args.token or "dry-run-placeholder"

    system_prompt = args.system_prompt or DEFAULT_SYSTEM_PROMPT

    # Resolve voice: prefer explicit --voice-id, then ELEVENLABS_VOICE_ID env, then Vapi default
    voice_id_env = os.environ.get("ELEVENLABS_VOICE_ID", "")
    voice_id = args.voice_id or voice_id_env or DEFAULT_VOICE_ID
    voice_provider = "11labs" if (args.voice_id or voice_id_env) else DEFAULT_VOICE_PROVIDER

    if voice_provider == "11labs":
        print(
            "Note: ElevenLabs voices require your ElevenLabs API key configured in the "
            "Vapi dashboard at dashboard.vapi.ai → Keys",
            file=sys.stderr,
        )

    assistant_payload = {
        "name": args.name,
        "model": {
            "provider": "anthropic",
            "model": "claude-opus-4-7",
            "systemPrompt": system_prompt,
            "temperature": 0.7,
            "maxTokens": 250,
        },
        "voice": {"provider": voice_provider, "voiceId": voice_id},
        "firstMessage": "Hey, this is Claude. What's on your mind?",
        "endCallFunctionEnabled": True,
        "endCallMessage": "Goodbye! Call back anytime.",
        "transcriber": {
            "provider": "deepgram",
            "model": "nova-2",
            "language": "en-US",
        },
        "silenceTimeoutSeconds": 30,
    }

    phone_payload_template = {
        "provider": "vapi",
        "areaCode": args.area_code,
        "assistantId": "<assistant_id from previous call>",
    }

    if args.dry_run:
        print("[DRY RUN] Assistant payload:")
        print(json.dumps(assistant_payload, indent=2))
        print("\n[DRY RUN] Phone number payload (assistantId filled after assistant creation):")
        print(json.dumps(phone_payload_template, indent=2))
        print("\n[DRY RUN] No API calls made. Remove --dry-run to provision for real.", file=sys.stderr)
        sys.exit(0)

    try:
        assistant = create_assistant(args.name, system_prompt, voice_provider, voice_id, token)
        assistant_id = assistant.get("id") or assistant.get("assistantId")
        if not assistant_id:
            raise RuntimeError(f"Unexpected assistant response: {json.dumps(assistant)[:200]}")

        phone = provision_phone_number(args.area_code, assistant_id, token)
        phone_number = phone.get("number") or phone.get("phoneNumber")
        if not phone_number:
            raise RuntimeError(f"Unexpected phone number response: {json.dumps(phone)[:200]}")

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    state = {
        "assistant_id": assistant_id,
        "assistant_name": args.name,
        "phone_number": phone_number,
        "voice_provider": voice_provider,
        "voice_id": voice_id,
        "created_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
    }

    try:
        save_state(state, args.output)
    except Exception as e:
        print(f"Warning: could not save state — {e}", file=sys.stderr)

    print(f"State saved to {args.output}\n", file=sys.stderr)
    print(
        f"  Your personal Claude assistant is live.\n\n"
        f"  Phone number : {phone_number}\n"
        f"  Assistant ID : {assistant_id}\n"
        f"  Voice        : {voice_id} ({voice_provider})\n\n"
        f"  Call now: dial {phone_number}\n"
        f"  Cost     : ~$0.25-0.33/minute (Vapi + Claude + voice)\n"
    )


if __name__ == "__main__":
    main()
