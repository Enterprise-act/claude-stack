"""Google Calendar task handler."""

from datetime import datetime, timedelta
from typing import Any

import structlog
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

from ..config import get_settings

logger = structlog.get_logger()


class CalendarTaskHandler:
    """Handle calendar-related tasks."""

    def __init__(self):
        settings = get_settings()
        self.credentials = Credentials(
            token=None,
            refresh_token=settings.google_refresh_token,
            token_uri="https://oauth2.googleapis.com/token",
            client_id=settings.google_client_id,
            client_secret=settings.google_client_secret,
        )
        self.service = build("calendar", "v3", credentials=self.credentials)

    async def __call__(
        self,
        text: str,
        entities: dict[str, Any],
        context: list[dict],
    ) -> str:
        """Handle a calendar task request."""
        action = self._determine_action(text, entities)

        if action == "list":
            return await self.list_upcoming_events(entities)
        elif action == "create":
            return await self.create_event(entities)
        elif action == "find_free":
            return await self.find_free_time(entities)
        else:
            return "I can help with calendar tasks. What would you like to do? (list events, schedule a meeting, find free time)"

    def _determine_action(self, text: str, entities: dict) -> str:
        """Determine what calendar action to take."""
        text_lower = text.lower()
        if any(w in text_lower for w in ["schedule", "create", "book", "set up"]):
            return "create"
        elif any(w in text_lower for w in ["free", "available", "open"]):
            return "find_free"
        else:
            return "list"

    async def list_upcoming_events(self, entities: dict) -> str:
        """List upcoming calendar events."""
        now = datetime.utcnow().isoformat() + "Z"
        days_ahead = entities.get("days", 7)
        end = (datetime.utcnow() + timedelta(days=days_ahead)).isoformat() + "Z"

        events_result = (
            self.service.events()
            .list(
                calendarId="primary",
                timeMin=now,
                timeMax=end,
                maxResults=10,
                singleEvents=True,
                orderBy="startTime",
            )
            .execute()
        )

        events = events_result.get("items", [])

        if not events:
            return f"No upcoming events in the next {days_ahead} days."

        lines = [f"**Upcoming events (next {days_ahead} days):**\n"]
        for event in events:
            start = event["start"].get("dateTime", event["start"].get("date"))
            dt = datetime.fromisoformat(start.replace("Z", "+00:00"))
            formatted = dt.strftime("%a %b %d, %I:%M %p")
            summary = event.get("summary", "No title")
            lines.append(f"- {formatted}: {summary}")

        return "\n".join(lines)

    async def create_event(self, entities: dict) -> str:
        """Create a calendar event (placeholder - needs more entity extraction)."""
        title = entities.get("title")
        date = entities.get("date")
        time = entities.get("time")
        attendees = entities.get("attendees", [])

        if not all([title, date, time]):
            missing = []
            if not title:
                missing.append("event title")
            if not date:
                missing.append("date")
            if not time:
                missing.append("time")
            return f"I need more details to create this event. Please provide: {', '.join(missing)}"

        return f"I'll create an event '{title}' for {date} at {time}. [Note: Full implementation requires datetime parsing and Google Meet integration]"

    async def find_free_time(self, entities: dict) -> str:
        """Find free time slots."""
        duration = entities.get("duration_minutes", 30)
        days_ahead = entities.get("days", 3)

        now = datetime.utcnow().isoformat() + "Z"
        end = (datetime.utcnow() + timedelta(days=days_ahead)).isoformat() + "Z"

        events_result = (
            self.service.events()
            .list(
                calendarId="primary",
                timeMin=now,
                timeMax=end,
                singleEvents=True,
                orderBy="startTime",
            )
            .execute()
        )

        events = events_result.get("items", [])

        return f"Found {len(events)} events in the next {days_ahead} days. [Free slot detection coming soon]"
