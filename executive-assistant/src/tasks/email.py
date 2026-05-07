"""Gmail task handler."""

import base64
from email.mime.text import MIMEText
from typing import Any

import structlog
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

from ..config import get_settings

logger = structlog.get_logger()


class EmailTaskHandler:
    """Handle email-related tasks."""

    def __init__(self):
        settings = get_settings()
        self.credentials = Credentials(
            token=None,
            refresh_token=settings.google_refresh_token,
            token_uri="https://oauth2.googleapis.com/token",
            client_id=settings.google_client_id,
            client_secret=settings.google_client_secret,
        )
        self.service = build("gmail", "v1", credentials=self.credentials)

    async def __call__(
        self,
        text: str,
        entities: dict[str, Any],
        context: list[dict],
    ) -> str:
        """Handle an email task request."""
        action = self._determine_action(text, entities)

        if action == "draft":
            return await self.draft_email(text, entities)
        elif action == "send":
            return await self.send_email(entities)
        elif action == "search":
            return await self.search_emails(entities)
        else:
            return "I can help with emails. Would you like to draft an email, send one, or search your inbox?"

    def _determine_action(self, text: str, entities: dict) -> str:
        """Determine what email action to take."""
        text_lower = text.lower()
        if any(w in text_lower for w in ["draft", "write", "compose"]):
            return "draft"
        elif any(w in text_lower for w in ["send", "reply"]):
            return "send"
        elif any(w in text_lower for w in ["search", "find", "look for"]):
            return "search"
        else:
            return "draft"

    async def draft_email(self, text: str, entities: dict) -> str:
        """Draft an email (returns draft content for approval)."""
        recipient = entities.get("recipient")
        subject = entities.get("subject")
        topic = entities.get("topic", text)

        if not recipient:
            return "Who should I send this email to? Please provide a name or email address."

        return f"""Here's a draft email for your review:

**To:** {recipient}
**Subject:** {subject or '[Please provide subject]'}

---

[I'll draft the email content based on your request. Please confirm or edit before sending.]

---

Reply with "send" to send, or provide edits."""

    async def send_email(self, entities: dict) -> str:
        """Send an email (requires confirmation)."""
        recipient = entities.get("recipient")
        subject = entities.get("subject")
        body = entities.get("body")

        if not all([recipient, subject, body]):
            return "I need recipient, subject, and body to send an email. Please provide all details."

        return f"Ready to send email to {recipient}. [Sending requires explicit confirmation - reply 'confirm send' to proceed]"

    async def search_emails(self, entities: dict) -> str:
        """Search emails."""
        query = entities.get("query", "")
        sender = entities.get("sender")
        subject = entities.get("subject")

        search_query = query
        if sender:
            search_query += f" from:{sender}"
        if subject:
            search_query += f" subject:{subject}"

        if not search_query:
            return "What would you like to search for in your emails? Provide keywords, sender name, or subject."

        try:
            results = (
                self.service.users()
                .messages()
                .list(userId="me", q=search_query, maxResults=5)
                .execute()
            )

            messages = results.get("messages", [])
            if not messages:
                return f"No emails found matching '{search_query}'"

            summaries = []
            for msg in messages[:5]:
                full = (
                    self.service.users()
                    .messages()
                    .get(userId="me", id=msg["id"], format="metadata")
                    .execute()
                )
                headers = {
                    h["name"]: h["value"]
                    for h in full.get("payload", {}).get("headers", [])
                }
                summaries.append(
                    f"- **{headers.get('Subject', 'No subject')}** from {headers.get('From', 'Unknown')}"
                )

            return f"Found {len(messages)} emails:\n" + "\n".join(summaries)

        except Exception as e:
            logger.error("email_search_failed", error=str(e))
            return f"Error searching emails: {str(e)[:100]}"

    def _create_message(self, to: str, subject: str, body: str) -> dict:
        """Create a Gmail message."""
        message = MIMEText(body)
        message["to"] = to
        message["subject"] = subject
        raw = base64.urlsafe_b64encode(message.as_bytes()).decode()
        return {"raw": raw}
