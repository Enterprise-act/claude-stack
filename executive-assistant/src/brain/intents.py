"""Intent classification for routing requests."""

from dataclasses import dataclass
from enum import Enum
from typing import Optional

import anthropic
import structlog

from ..config import get_settings

logger = structlog.get_logger()


class Intent(Enum):
    """Types of user intents."""

    QUESTION = "question"  # Needs information retrieval
    TASK_CALENDAR = "task_calendar"  # Schedule/calendar action
    TASK_EMAIL = "task_email"  # Send/draft email
    TASK_SLACK = "task_slack"  # Slack action (post, remind)
    TASK_FINANCIAL = "task_financial"  # QuickBooks lookup/action
    TASK_CRM = "task_crm"  # Frappe CRM action
    TASK_WORKFLOW = "task_workflow"  # Trigger n8n workflow
    CONVERSATION = "conversation"  # General chat, no action needed
    UNCLEAR = "unclear"  # Need clarification


@dataclass
class ClassifiedIntent:
    """Result of intent classification."""

    intent: Intent
    confidence: float
    entities: dict  # Extracted entities (dates, names, etc.)
    reasoning: str


class IntentClassifier:
    """Classify user intents using Claude."""

    def __init__(self):
        settings = get_settings()
        self.client = anthropic.AsyncAnthropic(api_key=settings.anthropic_api_key)

    async def classify(self, message: str, context: list[dict]) -> ClassifiedIntent:
        """Classify the intent of a user message."""
        context_summary = self._summarize_context(context)

        response = await self.client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=500,
            system="""You are an intent classifier for an enterprise assistant.
Classify the user's message into one of these intents:
- question: User wants information (lookup, search, explain)
- task_calendar: User wants to schedule, check, or modify calendar events
- task_email: User wants to send, draft, or check emails
- task_slack: User wants to post messages, set reminders in Slack
- task_financial: User wants QuickBooks data (invoices, clients, reports)
- task_crm: User wants CRM data or actions (Frappe)
- task_workflow: User wants to trigger an automated workflow
- conversation: General chat, greeting, thanks - no action needed
- unclear: Need more information to understand request

Respond in JSON format:
{
  "intent": "one_of_the_above",
  "confidence": 0.0-1.0,
  "entities": {"key": "value"},
  "reasoning": "brief explanation"
}

Extract relevant entities like:
- dates/times for calendar
- recipient names/emails for email
- channel names for slack
- client/invoice names for financial
- specific document/topic for questions""",
            messages=[
                {
                    "role": "user",
                    "content": f"Context from conversation:\n{context_summary}\n\nUser message: {message}",
                }
            ],
        )

        try:
            import json

            result = json.loads(response.content[0].text)
            return ClassifiedIntent(
                intent=Intent(result["intent"]),
                confidence=result.get("confidence", 0.8),
                entities=result.get("entities", {}),
                reasoning=result.get("reasoning", ""),
            )
        except (json.JSONDecodeError, KeyError, ValueError) as e:
            logger.warning("intent_classification_failed", error=str(e))
            return ClassifiedIntent(
                intent=Intent.UNCLEAR,
                confidence=0.5,
                entities={},
                reasoning=f"Failed to parse: {str(e)}",
            )

    def _summarize_context(self, context: list[dict]) -> str:
        """Summarize conversation context."""
        if not context:
            return "No prior context."

        lines = []
        for msg in context[-5:]:  # Last 5 messages
            role = "Bot" if msg.get("is_bot") else "User"
            text = msg.get("text", "")[:200]
            lines.append(f"{role}: {text}")

        return "\n".join(lines)
