"""QuickBooks connector - ingest client and financial data."""

from datetime import datetime, timedelta
from typing import AsyncIterator

import httpx
import structlog

from ..config import get_settings
from ..memory.vector_store import MemoryDocument, generate_doc_id
from .base import BaseConnector

logger = structlog.get_logger()

QB_BASE_URL = "https://quickbooks.api.intuit.com/v3/company"


class QuickBooksConnector(BaseConnector):
    """Ingest client and invoice data from QuickBooks."""

    source_name = "quickbooks"

    def __init__(self):
        settings = get_settings()
        self.client_id = settings.quickbooks_client_id
        self.client_secret = settings.quickbooks_client_secret
        self.realm_id = settings.quickbooks_realm_id
        self.refresh_token = settings.quickbooks_refresh_token
        self._access_token = None

    async def _get_access_token(self) -> str:
        """Get or refresh access token."""
        if self._access_token:
            return self._access_token

        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer",
                data={
                    "grant_type": "refresh_token",
                    "refresh_token": self.refresh_token,
                },
                auth=(self.client_id, self.client_secret),
            )
            response.raise_for_status()
            data = response.json()
            self._access_token = data["access_token"]
            return self._access_token

    async def _api_request(self, endpoint: str) -> dict:
        """Make authenticated API request."""
        token = await self._get_access_token()
        url = f"{QB_BASE_URL}/{self.realm_id}/{endpoint}"

        async with httpx.AsyncClient() as client:
            response = await client.get(
                url,
                headers={
                    "Authorization": f"Bearer {token}",
                    "Accept": "application/json",
                },
            )
            response.raise_for_status()
            return response.json()

    async def fetch_documents(self) -> AsyncIterator[MemoryDocument]:
        """Fetch all clients and recent invoices."""
        async for doc in self._fetch_customers():
            yield doc

        async for doc in self._fetch_invoices():
            yield doc

    async def fetch_incremental(
        self, since_timestamp: float
    ) -> AsyncIterator[MemoryDocument]:
        """Fetch data modified since timestamp."""
        since_date = datetime.fromtimestamp(since_timestamp).strftime("%Y-%m-%d")

        async for doc in self._fetch_customers(since_date):
            yield doc
        async for doc in self._fetch_invoices(since_date):
            yield doc

    async def _fetch_customers(
        self, since_date: str = None
    ) -> AsyncIterator[MemoryDocument]:
        """Fetch customer records."""
        query = "SELECT * FROM Customer"
        if since_date:
            query += f" WHERE MetaData.LastUpdatedTime > '{since_date}'"

        data = await self._api_request(f"query?query={query}")

        for customer in data.get("QueryResponse", {}).get("Customer", []):
            content = self._format_customer(customer)
            yield MemoryDocument(
                id=generate_doc_id("quickbooks", f"customer:{customer['Id']}"),
                content=content,
                source="quickbooks",
                source_id=f"customer:{customer['Id']}",
                metadata={
                    "type": "customer",
                    "name": customer.get("DisplayName", ""),
                    "company": customer.get("CompanyName", ""),
                    "email": customer.get("PrimaryEmailAddr", {}).get("Address", ""),
                },
            )

    async def _fetch_invoices(
        self, since_date: str = None
    ) -> AsyncIterator[MemoryDocument]:
        """Fetch invoice records."""
        if since_date is None:
            since_date = (datetime.now() - timedelta(days=365)).strftime("%Y-%m-%d")

        query = f"SELECT * FROM Invoice WHERE MetaData.CreateTime > '{since_date}'"
        data = await self._api_request(f"query?query={query}")

        for invoice in data.get("QueryResponse", {}).get("Invoice", []):
            content = self._format_invoice(invoice)
            yield MemoryDocument(
                id=generate_doc_id("quickbooks", f"invoice:{invoice['Id']}"),
                content=content,
                source="quickbooks",
                source_id=f"invoice:{invoice['Id']}",
                metadata={
                    "type": "invoice",
                    "invoice_number": invoice.get("DocNumber", ""),
                    "customer": invoice.get("CustomerRef", {}).get("name", ""),
                    "amount": invoice.get("TotalAmt", 0),
                    "date": invoice.get("TxnDate", ""),
                    "status": "paid" if invoice.get("Balance", 0) == 0 else "outstanding",
                },
            )

    def _format_customer(self, customer: dict) -> str:
        """Format customer data for indexing."""
        parts = [
            f"Customer: {customer.get('DisplayName', 'Unknown')}",
        ]

        if customer.get("CompanyName"):
            parts.append(f"Company: {customer['CompanyName']}")

        if customer.get("PrimaryEmailAddr"):
            parts.append(f"Email: {customer['PrimaryEmailAddr'].get('Address', '')}")

        if customer.get("PrimaryPhone"):
            parts.append(f"Phone: {customer['PrimaryPhone'].get('FreeFormNumber', '')}")

        if customer.get("BillAddr"):
            addr = customer["BillAddr"]
            addr_parts = [
                addr.get("Line1", ""),
                addr.get("City", ""),
                addr.get("CountrySubDivisionCode", ""),
                addr.get("PostalCode", ""),
            ]
            parts.append(f"Address: {', '.join(p for p in addr_parts if p)}")

        if customer.get("Notes"):
            parts.append(f"Notes: {customer['Notes']}")

        return "\n".join(parts)

    def _format_invoice(self, invoice: dict) -> str:
        """Format invoice data for indexing."""
        customer_name = invoice.get("CustomerRef", {}).get("name", "Unknown")
        total = invoice.get("TotalAmt", 0)
        balance = invoice.get("Balance", 0)
        status = "Paid" if balance == 0 else f"Outstanding: ${balance}"

        parts = [
            f"Invoice #{invoice.get('DocNumber', 'N/A')}",
            f"Customer: {customer_name}",
            f"Date: {invoice.get('TxnDate', 'Unknown')}",
            f"Total: ${total}",
            f"Status: {status}",
        ]

        if invoice.get("Line"):
            parts.append("Line items:")
            for line in invoice["Line"]:
                if line.get("DetailType") == "SalesItemLineDetail":
                    desc = line.get("Description", "Item")
                    amount = line.get("Amount", 0)
                    parts.append(f"  - {desc}: ${amount}")

        return "\n".join(parts)
