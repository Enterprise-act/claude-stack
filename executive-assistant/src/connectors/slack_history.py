"""Slack history connector - ingest channel history and important threads."""

from datetime import datetime, timedelta
from typing import AsyncIterator

import structlog
from slack_sdk.web.async_client import AsyncWebClient

from ..config import get_settings
from ..memory.vector_store import MemoryDocument, generate_doc_id
from .base import BaseConnector

logger = structlog.get_logger()


class SlackHistoryConnector(BaseConnector):
    """Ingest message history from Slack channels."""

    source_name = "slack"

    def __init__(self):
        settings = get_settings()
        self.client = AsyncWebClient(token=settings.slack_bot_token)
        self.channels_to_index = []  # Will be populated from config

    async def fetch_documents(self) -> AsyncIterator[MemoryDocument]:
        """Fetch all messages from configured channels."""
        channels = await self._get_channels()

        for channel in channels:
            async for doc in self._fetch_channel_history(channel):
                yield doc

    async def fetch_incremental(
        self, since_timestamp: float
    ) -> AsyncIterator[MemoryDocument]:
        """Fetch messages since timestamp."""
        channels = await self._get_channels()

        for channel in channels:
            async for doc in self._fetch_channel_history(
                channel, oldest=str(since_timestamp)
            ):
                yield doc

    async def _get_channels(self) -> list[dict]:
        """Get list of channels to index."""
        result = await self.client.conversations_list(
            types="public_channel,private_channel",
            limit=200,
        )
        return result.get("channels", [])

    async def _fetch_channel_history(
        self,
        channel: dict,
        oldest: str = None,
    ) -> AsyncIterator[MemoryDocument]:
        """Fetch message history from a channel."""
        channel_id = channel["id"]
        channel_name = channel.get("name", "unknown")

        cursor = None
        if oldest is None:
            oldest = str(
                (datetime.now() - timedelta(days=90)).timestamp()
            )  # Last 90 days

        while True:
            result = await self.client.conversations_history(
                channel=channel_id,
                oldest=oldest,
                limit=200,
                cursor=cursor,
            )

            for message in result.get("messages", []):
                if message.get("subtype"):
                    continue

                doc = await self._message_to_document(message, channel_id, channel_name)
                if doc:
                    yield doc

                if message.get("thread_ts") and message.get("reply_count", 0) > 2:
                    async for thread_doc in self._fetch_thread(
                        channel_id, channel_name, message["thread_ts"]
                    ):
                        yield thread_doc

            cursor = result.get("response_metadata", {}).get("next_cursor")
            if not cursor:
                break

    async def _fetch_thread(
        self,
        channel_id: str,
        channel_name: str,
        thread_ts: str,
    ) -> AsyncIterator[MemoryDocument]:
        """Fetch and combine thread messages into a single document."""
        result = await self.client.conversations_replies(
            channel=channel_id,
            ts=thread_ts,
            limit=100,
        )

        messages = result.get("messages", [])
        if len(messages) < 3:
            return

        thread_text = []
        users = set()
        for msg in messages:
            user = msg.get("user", "unknown")
            text = msg.get("text", "")
            thread_text.append(f"@{user}: {text}")
            users.add(user)

        combined_content = "\n".join(thread_text)

        yield MemoryDocument(
            id=generate_doc_id("slack", f"{channel_id}:{thread_ts}"),
            content=combined_content[:5000],
            source="slack",
            source_id=f"{channel_id}:{thread_ts}",
            metadata={
                "channel": channel_name,
                "channel_id": channel_id,
                "thread_ts": thread_ts,
                "message_count": len(messages),
                "participants": list(users),
                "date": datetime.fromtimestamp(float(thread_ts)).isoformat(),
            },
        )

    async def _message_to_document(
        self,
        message: dict,
        channel_id: str,
        channel_name: str,
    ) -> MemoryDocument | None:
        """Convert a single message to a document (only if substantive)."""
        text = message.get("text", "")

        if len(text) < 100:
            return None

        ts = message.get("ts", "")
        user = message.get("user", "unknown")

        return MemoryDocument(
            id=generate_doc_id("slack", f"{channel_id}:{ts}"),
            content=text[:3000],
            source="slack",
            source_id=f"{channel_id}:{ts}",
            metadata={
                "channel": channel_name,
                "channel_id": channel_id,
                "user": user,
                "date": datetime.fromtimestamp(float(ts)).isoformat() if ts else "",
            },
        )
