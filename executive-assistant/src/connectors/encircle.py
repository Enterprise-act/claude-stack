"""Encircle connector - ingest property documentation and inspections."""

from typing import AsyncIterator

import httpx
import structlog

from ..config import get_settings
from ..memory.vector_store import MemoryDocument, generate_doc_id
from .base import BaseConnector

logger = structlog.get_logger()

ENCIRCLE_API_URL = "https://api.encircleapp.com/v1"


class EncircleConnector(BaseConnector):
    """Ingest property documentation from Encircle."""

    source_name = "encircle"

    def __init__(self):
        settings = get_settings()
        self.api_key = settings.encircle_api_key
        self.company_id = settings.encircle_company_id

    @property
    def is_configured(self) -> bool:
        """Check if Encircle is configured."""
        return bool(self.api_key and self.company_id)

    async def _api_request(self, endpoint: str, params: dict = None) -> dict:
        """Make authenticated API request."""
        if not self.is_configured:
            raise RuntimeError("Encircle is not configured")

        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{ENCIRCLE_API_URL}/{endpoint}",
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "X-Company-ID": self.company_id,
                },
                params=params or {},
            )
            response.raise_for_status()
            return response.json()

    async def fetch_documents(self) -> AsyncIterator[MemoryDocument]:
        """Fetch all projects and their documentation."""
        if not self.is_configured:
            logger.warning("encircle_not_configured")
            return

        async for doc in self._fetch_projects():
            yield doc

    async def fetch_incremental(
        self, since_timestamp: float
    ) -> AsyncIterator[MemoryDocument]:
        """Fetch projects modified since timestamp."""
        async for doc in self.fetch_documents():
            yield doc

    async def _fetch_projects(self) -> AsyncIterator[MemoryDocument]:
        """Fetch all Encircle projects."""
        try:
            page = 1
            while True:
                data = await self._api_request(
                    "projects",
                    params={"page": page, "per_page": 100},
                )

                projects = data.get("projects", data.get("data", []))
                if not projects:
                    break

                for project in projects:
                    doc = await self._process_project(project)
                    if doc:
                        yield doc

                page += 1
                if len(projects) < 100:
                    break

        except Exception as e:
            logger.error("encircle_projects_fetch_failed", error=str(e))

    async def _process_project(self, project: dict) -> MemoryDocument | None:
        """Process a single Encircle project."""
        project_id = project.get("id", project.get("project_id"))
        if not project_id:
            return None

        content = self._format_project(project)

        try:
            rooms_data = await self._api_request(f"projects/{project_id}/rooms")
            rooms = rooms_data.get("rooms", rooms_data.get("data", []))
            if rooms:
                content += "\n\nRooms:\n" + self._format_rooms(rooms)
        except Exception:
            pass

        return MemoryDocument(
            id=generate_doc_id("encircle", str(project_id)),
            content=content[:8000],
            source="encircle",
            source_id=str(project_id),
            metadata={
                "type": "property_inspection",
                "project_name": project.get("name", project.get("project_name", "")),
                "address": project.get("address", ""),
                "status": project.get("status", ""),
                "client": project.get("client_name", project.get("customer", "")),
                "date": project.get("created_at", project.get("date", "")),
            },
        )

    def _format_project(self, project: dict) -> str:
        """Format project for indexing."""
        parts = [
            f"Property Inspection: {project.get('name', project.get('project_name', 'Unknown'))}",
        ]

        if project.get("address"):
            parts.append(f"Address: {project['address']}")

        if project.get("client_name") or project.get("customer"):
            parts.append(f"Client: {project.get('client_name', project.get('customer', ''))}")

        if project.get("status"):
            parts.append(f"Status: {project['status']}")

        if project.get("loss_type") or project.get("category"):
            parts.append(f"Type: {project.get('loss_type', project.get('category', ''))}")

        if project.get("notes") or project.get("description"):
            parts.append(f"Notes: {project.get('notes', project.get('description', ''))}")

        if project.get("insurance_company"):
            parts.append(f"Insurance: {project['insurance_company']}")

        if project.get("claim_number"):
            parts.append(f"Claim #: {project['claim_number']}")

        return "\n".join(parts)

    def _format_rooms(self, rooms: list) -> str:
        """Format room data."""
        lines = []
        for room in rooms[:20]:  # Limit rooms
            room_name = room.get("name", room.get("room_name", "Unknown Room"))
            room_type = room.get("type", room.get("room_type", ""))
            notes = room.get("notes", "")

            line = f"- {room_name}"
            if room_type:
                line += f" ({room_type})"
            if notes:
                line += f": {notes[:200]}"

            lines.append(line)

        return "\n".join(lines)
