"""Executive Assistant - the main brain orchestrating everything."""

from typing import Optional

import anthropic
import structlog

from ..config import get_settings
from ..memory.retrieval import MemoryRetriever
from .intents import Intent, IntentClassifier, ClassifiedIntent

logger = structlog.get_logger()

SYSTEM_PROMPT = """You are the FSP Executive Assistant, an AI assistant for the Full Service Pros team.

You have access to the company's enterprise memory - documents, emails, Slack history, financial records, CRM data, and property documentation.

Your role:
1. Answer questions using the company's knowledge base
2. Execute tasks when asked (scheduling, emails, lookups)
3. Be the team's source of truth for company information

Guidelines:
- Be concise and direct - the team values efficiency
- Cite sources when providing information: [Source: Google Doc "Title"] or [Source: Slack #channel]
- If you're not sure, say so - don't make up information
- For tasks that require action, confirm what you're about to do before executing
- Use the team member's name when addressing them

When you receive context from enterprise memory, use it to inform your response.
If the retrieved context doesn't contain the answer, say so clearly.

Current capabilities:
- Answer questions from enterprise memory (Google Drive, Slack, Gmail, QuickBooks, Frappe, Encircle)
- Look up financial data in QuickBooks
- Look up client/project info in Frappe CRM
- Search property documentation in Encircle
- [Coming soon] Schedule calendar events
- [Coming soon] Draft and send emails
- [Coming soon] Trigger n8n workflows"""


class ExecutiveAssistant:
    """Main assistant that orchestrates memory retrieval and task execution."""

    def __init__(self):
        settings = get_settings()
        self.client = anthropic.AsyncAnthropic(api_key=settings.anthropic_api_key)
        self.memory = MemoryRetriever()
        self.intent_classifier = IntentClassifier()
        self.task_handlers: dict = {}  # Will be populated with task executors

    def register_task_handler(self, intent: Intent, handler):
        """Register a handler for a specific intent type."""
        self.task_handlers[intent] = handler

    async def handle_message(
        self,
        channel: str,
        thread_ts: str,
        user: str,
        text: str,
        context: list[dict],
    ) -> str:
        """
        Handle an incoming message from Slack.

        This is the main entry point called by the Slack bot.
        """
        logger.info(
            "handling_message",
            user=user,
            text=text[:100],
            has_context=bool(context),
        )

        classified = await self.intent_classifier.classify(text, context)
        logger.info(
            "intent_classified",
            intent=classified.intent.value,
            confidence=classified.confidence,
        )

        if classified.intent == Intent.UNCLEAR:
            return await self._handle_unclear(text, classified)

        if classified.intent == Intent.CONVERSATION:
            return await self._handle_conversation(text, context)

        if classified.intent == Intent.QUESTION:
            return await self._handle_question(text, context)

        if classified.intent in self.task_handlers:
            handler = self.task_handlers[classified.intent]
            return await handler(text, classified.entities, context)

        return await self._handle_question(text, context)

    async def _handle_unclear(self, text: str, classified: ClassifiedIntent) -> str:
        """Handle unclear requests by asking for clarification."""
        response = await self.client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=300,
            system="You are a helpful assistant. The user's request was unclear. Ask a brief clarifying question.",
            messages=[{"role": "user", "content": text}],
        )
        return response.content[0].text

    async def _handle_conversation(self, text: str, context: list[dict]) -> str:
        """Handle general conversation (greetings, thanks, etc.)."""
        context_str = self._format_context(context)

        response = await self.client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=200,
            system="You are a friendly, professional executive assistant. Keep responses brief and warm.",
            messages=[
                {
                    "role": "user",
                    "content": f"Conversation context:\n{context_str}\n\nUser: {text}",
                }
            ],
        )
        return response.content[0].text

    async def _handle_question(self, text: str, context: list[dict]) -> str:
        """Handle questions by retrieving from enterprise memory."""
        retrieval = await self.memory.retrieve(query=text, limit=8)

        context_str = self._format_context(context)

        response = await self.client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1500,
            system=SYSTEM_PROMPT,
            messages=[
                {
                    "role": "user",
                    "content": f"""Conversation context:
{context_str}

Enterprise Memory (retrieved documents):
{retrieval.context_text}

---

User question: {text}

Answer the question using the enterprise memory above. Cite your sources.""",
                }
            ],
        )
        return response.content[0].text

    def _format_context(self, context: list[dict]) -> str:
        """Format conversation context for the prompt."""
        if not context:
            return "No prior conversation."

        lines = []
        for msg in context[-8:]:
            role = "Assistant" if msg.get("is_bot") else "User"
            text = msg.get("text", "")[:300]
            lines.append(f"{role}: {text}")

        return "\n".join(lines)

    async def direct_query(self, query: str) -> str:
        """Direct query without Slack context (for API use)."""
        return await self._handle_question(query, [])
