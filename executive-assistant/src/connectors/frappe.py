"""Frappe ERP/CRM connector - ingest CRM and project data."""

from typing import AsyncIterator

import httpx
import structlog

from ..config import get_settings
from ..memory.vector_store import MemoryDocument, generate_doc_id
from .base import BaseConnector

logger = structlog.get_logger()


class FrappeConnector(BaseConnector):
    """Ingest data from Frappe ERP/CRM."""

    source_name = "frappe"

    def __init__(self):
        settings = get_settings()
        self.base_url = settings.frappe_url
        self.api_key = settings.frappe_api_key
        self.api_secret = settings.frappe_api_secret

    @property
    def is_configured(self) -> bool:
        """Check if Frappe is configured."""
        return bool(self.base_url and self.api_key and self.api_secret)

    async def _api_request(self, endpoint: str, params: dict = None) -> dict:
        """Make authenticated API request."""
        if not self.is_configured:
            raise RuntimeError("Frappe is not configured")

        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/api/resource/{endpoint}",
                headers={
                    "Authorization": f"token {self.api_key}:{self.api_secret}",
                },
                params=params or {},
            )
            response.raise_for_status()
            return response.json()

    async def fetch_documents(self) -> AsyncIterator[MemoryDocument]:
        """Fetch all customers, leads, and projects."""
        if not self.is_configured:
            logger.warning("frappe_not_configured")
            return

        async for doc in self._fetch_customers():
            yield doc

        async for doc in self._fetch_leads():
            yield doc

        async for doc in self._fetch_projects():
            yield doc

    async def fetch_incremental(
        self, since_timestamp: float
    ) -> AsyncIterator[MemoryDocument]:
        """Fetch data modified since timestamp."""
        async for doc in self.fetch_documents():
            yield doc

    async def _fetch_customers(self) -> AsyncIterator[MemoryDocument]:
        """Fetch customer records."""
        try:
            data = await self._api_request(
                "Customer",
                params={"fields": '["*"]', "limit_page_length": 1000},
            )

            for customer in data.get("data", []):
                content = self._format_customer(customer)
                yield MemoryDocument(
                    id=generate_doc_id("frappe", f"customer:{customer['name']}"),
                    content=content,
                    source="frappe",
                    source_id=f"customer:{customer['name']}",
                    metadata={
                        "type": "customer",
                        "name": customer.get("customer_name", ""),
                        "territory": customer.get("territory", ""),
                        "customer_group": customer.get("customer_group", ""),
                    },
                )
        except Exception as e:
            logger.error("frappe_customers_fetch_failed", error=str(e))

    async def _fetch_leads(self) -> AsyncIterator[MemoryDocument]:
        """Fetch lead records."""
        try:
            data = await self._api_request(
                "Lead",
                params={"fields": '["*"]', "limit_page_length": 1000},
            )

            for lead in data.get("data", []):
                content = self._format_lead(lead)
                yield MemoryDocument(
                    id=generate_doc_id("frappe", f"lead:{lead['name']}"),
                    content=content,
                    source="frappe",
                    source_id=f"lead:{lead['name']}",
                    metadata={
                        "type": "lead",
                        "name": lead.get("lead_name", ""),
                        "status": lead.get("status", ""),
                        "source": lead.get("source", ""),
                    },
                )
        except Exception as e:
            logger.error("frappe_leads_fetch_failed", error=str(e))

    async def _fetch_projects(self) -> AsyncIterator[MemoryDocument]:
        """Fetch project records."""
        try:
            data = await self._api_request(
                "Project",
                params={"fields": '["*"]', "limit_page_length": 500},
            )

            for project in data.get("data", []):
                content = self._format_project(project)
                yield MemoryDocument(
                    id=generate_doc_id("frappe", f"project:{project['name']}"),
                    content=content,
                    source="frappe",
                    source_id=f"project:{project['name']}",
                    metadata={
                        "type": "project",
                        "name": project.get("project_name", ""),
                        "status": project.get("status", ""),
                        "customer": project.get("customer", ""),
                    },
                )
        except Exception as e:
            logger.error("frappe_projects_fetch_failed", error=str(e))

    def _format_customer(self, customer: dict) -> str:
        """Format customer for indexing."""
        parts = [
            f"Customer: {customer.get('customer_name', 'Unknown')}",
            f"Group: {customer.get('customer_group', 'N/A')}",
            f"Territory: {customer.get('territory', 'N/A')}",
        ]
        if customer.get("website"):
            parts.append(f"Website: {customer['website']}")
        if customer.get("mobile_no"):
            parts.append(f"Mobile: {customer['mobile_no']}")
        return "\n".join(parts)

    def _format_lead(self, lead: dict) -> str:
        """Format lead for indexing."""
        parts = [
            f"Lead: {lead.get('lead_name', 'Unknown')}",
            f"Status: {lead.get('status', 'N/A')}",
            f"Source: {lead.get('source', 'N/A')}",
        ]
        if lead.get("company_name"):
            parts.append(f"Company: {lead['company_name']}")
        if lead.get("email_id"):
            parts.append(f"Email: {lead['email_id']}")
        if lead.get("notes"):
            parts.append(f"Notes: {lead['notes']}")
        return "\n".join(parts)

    def _format_project(self, project: dict) -> str:
        """Format project for indexing."""
        parts = [
            f"Project: {project.get('project_name', 'Unknown')}",
            f"Status: {project.get('status', 'N/A')}",
            f"Customer: {project.get('customer', 'N/A')}",
        ]
        if project.get("expected_start_date"):
            parts.append(f"Start: {project['expected_start_date']}")
        if project.get("expected_end_date"):
            parts.append(f"End: {project['expected_end_date']}")
        if project.get("notes"):
            parts.append(f"Notes: {project['notes']}")
        return "\n".join(parts)
