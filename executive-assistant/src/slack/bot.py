"""Slack bot - handles @mentions and events."""

import asyncio
import re
from typing import Callable, Optional

import structlog
from slack_bolt.async_app import AsyncApp
from slack_bolt.adapter.socket_mode.async_handler import AsyncSocketModeHandler
from slack_sdk.web.async_client import AsyncWebClient

from ..config import get_settings

logger = structlog.get_logger()


class SlackBot:
    """Slack bot that responds to @mentions."""

    def __init__(self, message_handler: Callable):
        """
        Initialize the Slack bot.

        Args:
            message_handler: Async function(channel, thread_ts, user, text, context) -> str
                             Called when bot is mentioned. Returns response text.
        """
        settings = get_settings()

        self.app = AsyncApp(
            token=settings.slack_bot_token,
            signing_secret=settings.slack_signing_secret,
        )
        self.bot_user_id = settings.slack_bot_user_id
        self.message_handler = message_handler

        self._register_handlers()

    def _register_handlers(self):
        """Register Slack event handlers."""

        @self.app.event("app_mention")
        async def handle_mention(event: dict, client: AsyncWebClient):
            """Handle @mentions of the bot."""
            await self._process_mention(event, client)

        @self.app.event("message")
        async def handle_message(event: dict, client: AsyncWebClient):
            """Handle direct messages to the bot."""
            if event.get("channel_type") == "im":
                await self._process_dm(event, client)

    async def _process_mention(self, event: dict, client: AsyncWebClient):
        """Process an @mention event."""
        channel = event["channel"]
        thread_ts = event.get("thread_ts") or event["ts"]
        user = event["user"]
        text = self._clean_mention(event["text"])

        logger.info(
            "mention_received",
            channel=channel,
            user=user,
            text=text[:100],
        )

        await client.reactions_add(channel=channel, timestamp=event["ts"], name="eyes")

        try:
            context = await self._gather_thread_context(client, channel, thread_ts)

            response = await self.message_handler(
                channel=channel,
                thread_ts=thread_ts,
                user=user,
                text=text,
                context=context,
            )

            await client.chat_postMessage(
                channel=channel,
                thread_ts=thread_ts,
                text=response,
            )

            await client.reactions_add(
                channel=channel, timestamp=event["ts"], name="white_check_mark"
            )

        except Exception as e:
            logger.error("mention_handler_error", error=str(e))
            await client.chat_postMessage(
                channel=channel,
                thread_ts=thread_ts,
                text=f"Sorry, I encountered an error: {str(e)[:200]}",
            )
            await client.reactions_add(
                channel=channel, timestamp=event["ts"], name="x"
            )

    async def _process_dm(self, event: dict, client: AsyncWebClient):
        """Process a direct message."""
        if event.get("bot_id"):
            return

        channel = event["channel"]
        user = event["user"]
        text = event.get("text", "")
        thread_ts = event.get("thread_ts") or event["ts"]

        logger.info("dm_received", user=user, text=text[:100])

        try:
            context = await self._gather_thread_context(client, channel, thread_ts)

            response = await self.message_handler(
                channel=channel,
                thread_ts=thread_ts,
                user=user,
                text=text,
                context=context,
            )

            await client.chat_postMessage(
                channel=channel,
                thread_ts=thread_ts,
                text=response,
            )

        except Exception as e:
            logger.error("dm_handler_error", error=str(e))
            await client.chat_postMessage(
                channel=channel,
                thread_ts=thread_ts,
                text=f"Sorry, I encountered an error: {str(e)[:200]}",
            )

    def _clean_mention(self, text: str) -> str:
        """Remove bot mention from text."""
        pattern = rf"<@{self.bot_user_id}>\s*"
        return re.sub(pattern, "", text).strip()

    async def _gather_thread_context(
        self,
        client: AsyncWebClient,
        channel: str,
        thread_ts: str,
    ) -> list[dict]:
        """Gather conversation context from thread."""
        try:
            result = await client.conversations_replies(
                channel=channel,
                ts=thread_ts,
                limit=20,
            )
            messages = result.get("messages", [])

            return [
                {
                    "user": msg.get("user", "unknown"),
                    "text": msg.get("text", ""),
                    "ts": msg.get("ts"),
                    "is_bot": bool(msg.get("bot_id")),
                }
                for msg in messages
            ]
        except Exception as e:
            logger.warning("failed_to_get_thread_context", error=str(e))
            return []

    async def start(self):
        """Start the bot using Socket Mode."""
        settings = get_settings()
        handler = AsyncSocketModeHandler(self.app, settings.slack_app_token)
        logger.info("slack_bot_starting")
        await handler.start_async()

    async def send_message(
        self,
        channel: str,
        text: str,
        thread_ts: Optional[str] = None,
    ):
        """Send a message to a channel."""
        await self.app.client.chat_postMessage(
            channel=channel,
            text=text,
            thread_ts=thread_ts,
        )
