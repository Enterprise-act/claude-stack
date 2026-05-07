"""Google Drive connector - ingest documents, sheets, slides."""

from datetime import datetime
from typing import AsyncIterator, Optional

import structlog
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

from ..config import get_settings
from ..memory.vector_store import MemoryDocument, generate_doc_id
from .base import BaseConnector

logger = structlog.get_logger()

SUPPORTED_MIME_TYPES = [
    "application/vnd.google-apps.document",  # Google Docs
    "application/vnd.google-apps.spreadsheet",  # Google Sheets
    "application/vnd.google-apps.presentation",  # Google Slides
    "text/plain",
    "application/pdf",
]


class GoogleDriveConnector(BaseConnector):
    """Ingest documents from Google Drive."""

    source_name = "gdrive"

    def __init__(self):
        settings = get_settings()
        self.credentials = Credentials(
            token=None,
            refresh_token=settings.google_refresh_token,
            token_uri="https://oauth2.googleapis.com/token",
            client_id=settings.google_client_id,
            client_secret=settings.google_client_secret,
        )
        self.drive_service = build("drive", "v3", credentials=self.credentials)
        self.docs_service = build("docs", "v1", credentials=self.credentials)

    async def fetch_documents(self) -> AsyncIterator[MemoryDocument]:
        """Fetch all documents from Drive."""
        page_token = None

        while True:
            results = (
                self.drive_service.files()
                .list(
                    pageSize=100,
                    fields="nextPageToken, files(id, name, mimeType, modifiedTime, owners)",
                    q=f"mimeType = 'application/vnd.google-apps.document' or mimeType = 'application/vnd.google-apps.spreadsheet'",
                    pageToken=page_token,
                )
                .execute()
            )

            for file in results.get("files", []):
                doc = await self._process_file(file)
                if doc:
                    yield doc

            page_token = results.get("nextPageToken")
            if not page_token:
                break

    async def fetch_incremental(
        self, since_timestamp: float
    ) -> AsyncIterator[MemoryDocument]:
        """Fetch documents modified since timestamp."""
        since_dt = datetime.fromtimestamp(since_timestamp).isoformat() + "Z"

        results = (
            self.drive_service.files()
            .list(
                pageSize=100,
                fields="files(id, name, mimeType, modifiedTime, owners)",
                q=f"modifiedTime > '{since_dt}'",
            )
            .execute()
        )

        for file in results.get("files", []):
            doc = await self._process_file(file)
            if doc:
                yield doc

    async def _process_file(self, file: dict) -> Optional[MemoryDocument]:
        """Process a single file into a MemoryDocument."""
        file_id = file["id"]
        mime_type = file.get("mimeType", "")

        try:
            if mime_type == "application/vnd.google-apps.document":
                content = await self._extract_doc_content(file_id)
            elif mime_type == "application/vnd.google-apps.spreadsheet":
                content = await self._extract_sheet_content(file_id)
            else:
                logger.debug("skipping_unsupported_mime", mime_type=mime_type)
                return None

            if not content or len(content) < 50:
                return None

            owners = file.get("owners", [])
            owner_name = owners[0].get("displayName", "Unknown") if owners else "Unknown"

            return MemoryDocument(
                id=generate_doc_id("gdrive", file_id),
                content=content[:10000],  # Limit content size
                source="gdrive",
                source_id=file_id,
                metadata={
                    "title": file.get("name", "Untitled"),
                    "author": owner_name,
                    "date": file.get("modifiedTime", ""),
                    "mime_type": mime_type,
                },
            )

        except Exception as e:
            logger.error("failed_to_process_file", file_id=file_id, error=str(e))
            return None

    async def _extract_doc_content(self, doc_id: str) -> str:
        """Extract text content from a Google Doc."""
        doc = self.docs_service.documents().get(documentId=doc_id).execute()
        content_parts = []

        for element in doc.get("body", {}).get("content", []):
            if "paragraph" in element:
                for elem in element["paragraph"].get("elements", []):
                    if "textRun" in elem:
                        content_parts.append(elem["textRun"].get("content", ""))

        return "".join(content_parts)

    async def _extract_sheet_content(self, sheet_id: str) -> str:
        """Extract content from a Google Sheet (first sheet, headers + sample)."""
        sheets_service = build("sheets", "v4", credentials=self.credentials)

        result = (
            sheets_service.spreadsheets()
            .values()
            .get(spreadsheetId=sheet_id, range="A1:Z100")
            .execute()
        )

        values = result.get("values", [])
        if not values:
            return ""

        lines = []
        for row in values[:50]:  # First 50 rows
            lines.append(" | ".join(str(cell) for cell in row))

        return "\n".join(lines)
