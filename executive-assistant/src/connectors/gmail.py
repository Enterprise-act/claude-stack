"""Gmail connector - ingest email threads."""

import base64
from datetime import datetime, timedelta
from typing import AsyncIterator

import structlog
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

from ..config import get_settings
from ..memory.vector_store import MemoryDocument, generate_doc_id
from .base import BaseConnector

logger = structlog.get_logger()


class GmailConnector(BaseConnector):
    """Ingest email threads from Gmail."""

    source_name = "gmail"

    def __init__(self, refresh_token: str = None):
        settings = get_settings()
        self.credentials = Credentials(
            token=None,
            refresh_token=refresh_token or settings.google_refresh_token,
            token_uri="https://oauth2.googleapis.com/token",
            client_id=settings.google_client_id,
            client_secret=settings.google_client_secret,
        )
        self.service = build("gmail", "v1", credentials=self.credentials)

    async def fetch_documents(self) -> AsyncIterator[MemoryDocument]:
        """Fetch email threads from the last 90 days."""
        after_date = (datetime.now() - timedelta(days=90)).strftime("%Y/%m/%d")
        query = f"after:{after_date}"

        async for doc in self._fetch_threads(query):
            yield doc

    async def fetch_incremental(
        self, since_timestamp: float
    ) -> AsyncIterator[MemoryDocument]:
        """Fetch threads modified since timestamp."""
        since_date = datetime.fromtimestamp(since_timestamp).strftime("%Y/%m/%d")
        query = f"after:{since_date}"

        async for doc in self._fetch_threads(query):
            yield doc

    async def _fetch_threads(self, query: str) -> AsyncIterator[MemoryDocument]:
        """Fetch and process email threads."""
        page_token = None

        while True:
            results = (
                self.service.users()
                .threads()
                .list(userId="me", q=query, pageToken=page_token, maxResults=100)
                .execute()
            )

            for thread_meta in results.get("threads", []):
                doc = await self._process_thread(thread_meta["id"])
                if doc:
                    yield doc

            page_token = results.get("nextPageToken")
            if not page_token:
                break

    async def _process_thread(self, thread_id: str) -> MemoryDocument | None:
        """Process a single email thread."""
        try:
            thread = (
                self.service.users()
                .threads()
                .get(userId="me", id=thread_id, format="full")
                .execute()
            )

            messages = thread.get("messages", [])
            if not messages:
                return None

            first_msg = messages[0]
            headers = {
                h["name"].lower(): h["value"]
                for h in first_msg.get("payload", {}).get("headers", [])
            }

            subject = headers.get("subject", "No Subject")
            from_addr = headers.get("from", "Unknown")
            date = headers.get("date", "")

            thread_content = []
            participants = set()

            for msg in messages:
                msg_headers = {
                    h["name"].lower(): h["value"]
                    for h in msg.get("payload", {}).get("headers", [])
                }
                sender = msg_headers.get("from", "Unknown")
                participants.add(sender.split("<")[0].strip())

                body = self._extract_body(msg)
                if body:
                    thread_content.append(f"From: {sender}\n{body[:2000]}")

            if not thread_content:
                return None

            combined = f"Subject: {subject}\n\n" + "\n\n---\n\n".join(thread_content)

            return MemoryDocument(
                id=generate_doc_id("gmail", thread_id),
                content=combined[:8000],
                source="gmail",
                source_id=thread_id,
                metadata={
                    "subject": subject,
                    "from": from_addr,
                    "date": date,
                    "message_count": len(messages),
                    "participants": list(participants),
                },
            )

        except Exception as e:
            logger.error("failed_to_process_thread", thread_id=thread_id, error=str(e))
            return None

    def _extract_body(self, message: dict) -> str:
        """Extract plain text body from message."""
        payload = message.get("payload", {})

        if payload.get("body", {}).get("data"):
            return base64.urlsafe_b64decode(payload["body"]["data"]).decode(
                "utf-8", errors="ignore"
            )

        for part in payload.get("parts", []):
            if part.get("mimeType") == "text/plain":
                data = part.get("body", {}).get("data", "")
                if data:
                    return base64.urlsafe_b64decode(data).decode(
                        "utf-8", errors="ignore"
                    )

            if part.get("parts"):
                for subpart in part["parts"]:
                    if subpart.get("mimeType") == "text/plain":
                        data = subpart.get("body", {}).get("data", "")
                        if data:
                            return base64.urlsafe_b64decode(data).decode(
                                "utf-8", errors="ignore"
                            )

        return ""
