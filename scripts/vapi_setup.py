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
    python3 vapi_setup.py --status
    python3 vapi_setup.py --teardown
    python3 vapi_setup.py --token YOUR_KEY --area-code 415
"""

import argparse
import datetime
import json
import os
import sys
import time
import urllib.error
import urllib.request
import ssl

VAPI_BASE = "https://api.vapi.ai"
DEFAULT_VOICE_PROVIDER = "vapi"
DEFAULT_VOICE_ID = "will"
STATE_FILE = os.path.expanduser("~/.claude/vapi-assistant.json")

# Vapi native voice IDs — anything not in this set is treated as ElevenLabs
VAPI_NATIVE_VOICES = {"will", "mark", "ryan", "jennifer", "sarah"}

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


def _api_call(method: str, path: str, body: dict = None, token: str = "", retries: int = 3) -> dict:
    """Minimal Vapi API client (stdlib only). Retries on transient 5xx / network errors."""
    url = f"{VAPI_BASE}{path}"
    data = json.dumps(body).encode() if body else None
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": f"Bearer {token}",
    }
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    ctx = ssl.create_default_context()
    last_err = None
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, context=ctx, timeout=30) as resp:
                return json.loads(resp.read())
        except urllib.error.HTTPError as e:
            body_text = e.read().decode()[:300]
            if 400 <= e.code < 500:
                # 4xx — caller error, no point retrying
                raise RuntimeError(f"Vapi API {method} {path} → {e.code}: {body_text}")
            last_err = RuntimeError(f"Vapi API {method} {path} → {e.code}: {body_text}")
        except (urllib.error.URLError, OSError) as e:
            last_err = RuntimeError(f"Network error on {method} {path}: {e}")
        if attempt < retries - 1:
            wait = 2 ** attempt
            print(f"Retrying in {wait}s...", file=sys.stderr)
            time.sleep(wait)
    raise last_err


def _api_delete(path: str, token: str) -> None:
    """DELETE call — Vapi returns 200/204 with no body on success."""
    url = f"{VAPI_BASE}{path}"
    req = urllib.request.Request(
        url,
        headers={"Accept": "application/json", "Authorization": f"Bearer {token}"},
        method="DELETE",
    )
    ctx = ssl.create_default_context()
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=30) as resp:
            resp.read()
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"Vapi API DELETE {path} → {e.code}: {e.read().decode()[:300]}")


def resolve_voice(voice_id_flag: str) -> tuple:
    """Return (provider, voice_id). Vapi native voices stay on 'vapi'; others go to '11labs'."""
    voice_id_env = os.environ.get("ELEVENLABS_VOICE_ID", "")
    voice_id = voice_id_flag or voice_id_env or DEFAULT_VOICE_ID
    if voice_id in VAPI_NATIVE_VOICES:
        return DEFAULT_VOICE_PROVIDER, voice_id
    print(
        "Note: ElevenLabs voices require your ElevenLabs API key configured in the "
        "Vapi dashboard at dashboard.vapi.ai → Keys",
        file=sys.stderr,
    )
    return "11labs", voice_id


def create_assistant(
    name: str, system_prompt: str, voice_provider: str, voice_id: str,
    model: str, max_tokens: int, first_message: str, token: str
) -> dict:
    print(f"Creating assistant '{name}'...", file=sys.stderr)
    payload = {
        "name": name,
        "model": {
            "provider": "anthropic",
            "model": model,
            "systemPrompt": system_prompt,
            "temperature": 0.7,
            "maxTokens": max_tokens,
        },
        "voice": {
            "provider": voice_provider,
            "voiceId": voice_id,
        },
        "firstMessage": first_message,
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


def save_state(data: dict, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.islink(path):
        raise RuntimeError(f"State file path {path} is a symlink — aborting.")
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
    os.chmod(path, 0o600)


def load_state(path: str) -> dict:
    if not os.path.exists(path):
        print("No assistant configured yet. Run vapi_setup.py without flags to provision one.", file=sys.stderr)
        sys.exit(1)
    with open(path) as f:
        return json.load(f)


def cmd_status(state_path: str) -> None:
    state = load_state(state_path)
    print(f"\n  Assistant : {state.get('assistant_name', 'Claude')}")
    print(f"  Phone     : {state.get('phone_number')}")
    print(f"  ID        : {state.get('assistant_id')}")
    print(f"  Voice     : {state.get('voice_id')} ({state.get('voice_provider')})")
    print(f"  Model     : {state.get('model', 'claude-opus-4-7')}")
    print(f"  Created   : {state.get('created_at')}")
    print(f"\n  Manage    : dashboard.vapi.ai → Assistants")
    print(f"  Teardown  : python3 vapi_setup.py --teardown\n")


def cmd_teardown(state_path: str, token: str) -> None:
    state = load_state(state_path)
    assistant_id = state.get("assistant_id")
    phone_number = state.get("phone_number")
    phone_id = state.get("phone_id")

    print(f"Tearing down assistant '{state.get('assistant_name')}' ({phone_number})...", file=sys.stderr)
    errors = []

    if assistant_id:
        try:
            _api_delete(f"/assistant/{assistant_id}", token)
            print("  assistant deleted", file=sys.stderr)
        except Exception as e:
            errors.append(str(e))
            print(f"  assistant delete failed: {e}", file=sys.stderr)

    if phone_id:
        try:
            _api_delete(f"/phone-number/{phone_id}", token)
            print("  phone number released", file=sys.stderr)
        except Exception as e:
            errors.append(str(e))
            print(f"  phone delete failed: {e}", file=sys.stderr)
    else:
        print(
            f"  phone ID not in state — release {phone_number} manually at "
            "dashboard.vapi.ai → Phone Numbers",
            file=sys.stderr,
        )

    if not errors:
        os.remove(state_path)
        print("Teardown complete. No active resources or billing.", file=sys.stderr)
    else:
        print("\nPartial teardown — check dashboard.vapi.ai for remaining resources.", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Set up a personal Claude voice assistant via Vapi.ai")
    parser.add_argument("--name", default="Claude",
                        help="Display name for the assistant (default: Claude)")
    parser.add_argument("--area-code", default="415",
                        help="3-digit US area code for the phone number (default: 415)")
    parser.add_argument("--voice-id", default="",
                        help="Vapi native or ElevenLabs voice ID (default: will)")
    parser.add_argument("--model", default="claude-opus-4-7",
                        help="Claude model to use (default: claude-opus-4-7)")
    parser.add_argument("--max-tokens", type=int, default=250,
                        help="Max response tokens (default: 250)")
    parser.add_argument("--first-message", default="Hey, this is Claude. What's on your mind?",
                        help="Opening line when a call connects")
    parser.add_argument("--system-prompt", default="",
                        help="Custom system prompt inline (overrides built-in default)")
    parser.add_argument("--system-prompt-file", default="",
                        help="Path to a .txt file containing the system prompt")
    parser.add_argument("--token", default=os.environ.get("VAPI_API_KEY", ""),
                        help="Vapi API key (or set VAPI_API_KEY env var)")
    parser.add_argument("--output", default=STATE_FILE,
                        help=f"Path to save state JSON (default: {STATE_FILE})")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print API payloads without making any calls")
    parser.add_argument("--status", action="store_true",
                        help="Show current assistant config and phone number")
    parser.add_argument("--teardown", action="store_true",
                        help="Delete the assistant and release the phone number")
    args = parser.parse_args()

    state_path = args.output

    if args.status:
        cmd_status(state_path)
        return

    if args.teardown:
        if not args.token:
            print("Error: --teardown requires VAPI_API_KEY or --token", file=sys.stderr)
            sys.exit(1)
        cmd_teardown(state_path, args.token)
        return

    if not args.token and not args.dry_run:
        print(
            "Error: Vapi API key required.\n"
            "  Sign up free at https://vapi.ai\n"
            "  Then: export VAPI_API_KEY=your_key",
            file=sys.stderr,
        )
        sys.exit(1)

    token = args.token or "dry-run-placeholder"

    if args.system_prompt_file:
        with open(args.system_prompt_file) as f:
            system_prompt = f.read().strip()
    else:
        system_prompt = args.system_prompt or DEFAULT_SYSTEM_PROMPT

    voice_provider, voice_id = resolve_voice(args.voice_id)

    assistant_payload = {
        "name": args.name,
        "model": {
            "provider": "anthropic",
            "model": args.model,
            "systemPrompt": system_prompt,
            "temperature": 0.7,
            "maxTokens": args.max_tokens,
        },
        "voice": {"provider": voice_provider, "voiceId": voice_id},
        "firstMessage": args.first_message,
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

    assistant_id = None
    try:
        assistant = create_assistant(
            args.name, system_prompt, voice_provider, voice_id,
            args.model, args.max_tokens, args.first_message, token,
        )
        assistant_id = assistant.get("id") or assistant.get("assistantId")
        if not assistant_id:
            raise RuntimeError(f"Unexpected assistant response: {json.dumps(assistant)[:200]}")

        phone = provision_phone_number(args.area_code, assistant_id, token)
        phone_number = phone.get("number") or phone.get("phoneNumber")
        phone_id = phone.get("id") or phone.get("phoneNumberId")
        if not phone_number:
            raise RuntimeError(f"Unexpected phone number response: {json.dumps(phone)[:200]}")

    except Exception as e:
        if assistant_id:
            # Phone provisioning failed after assistant was created — roll back to avoid leaking resources
            print(f"Rolling back assistant {assistant_id}...", file=sys.stderr)
            try:
                _api_delete(f"/assistant/{assistant_id}", token)
                print("Rollback complete. No resources were leaked.", file=sys.stderr)
            except Exception as rb_err:
                print(
                    f"Rollback also failed: {rb_err}\n"
                    f"Delete assistant manually: dashboard.vapi.ai → Assistants → {assistant_id}",
                    file=sys.stderr,
                )
        print(f"\nError: {e}", file=sys.stderr)
        sys.exit(1)

    state = {
        "assistant_id": assistant_id,
        "assistant_name": args.name,
        "phone_number": phone_number,
        "phone_id": phone_id,
        "voice_provider": voice_provider,
        "voice_id": voice_id,
        "model": args.model,
        "created_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
    }

    try:
        save_state(state, state_path)
        print(f"State saved to {state_path}\n", file=sys.stderr)
    except Exception as e:
        print(f"Warning: could not save state — {e}", file=sys.stderr)

    print(
        f"  Your personal Claude assistant is live.\n\n"
        f"  Phone number : {phone_number}\n"
        f"  Assistant ID : {assistant_id}\n"
        f"  Voice        : {voice_id} ({voice_provider})\n"
        f"  Model        : {args.model}\n\n"
        f"  Call now : dial {phone_number}\n"
        f"  Status   : python3 vapi_setup.py --status\n"
        f"  Teardown : python3 vapi_setup.py --teardown\n"
        f"  Cost     : ~$0.25-0.33/minute (Vapi + Claude + voice)\n"
    )


if __name__ == "__main__":
    main()
