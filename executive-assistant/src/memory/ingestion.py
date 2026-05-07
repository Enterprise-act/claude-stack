"""Ingestion orchestrator - coordinate data source syncing."""

import asyncio
from datetime import datetime
from typing import Optional

import structlog

from .embeddings import EmbeddingService
from .vector_store import VectorStore, MemoryDocument
from ..connectors.base import BaseConnector
from ..connectors.google_drive import GoogleDriveConnector
from ..connectors.slack_history import SlackHistoryConnector
from ..connectors.gmail import GmailConnector
from ..connectors.quickbooks import QuickBooksConnector
from ..connectors.frappe import FrappeConnector
from ..connectors.encircle import EncircleConnector

logger = structlog.get_logger()


class IngestionOrchestrator:
    """Orchestrate data ingestion from all sources."""

    def __init__(self):
        self.embeddings = EmbeddingService()
        self.vector_store = VectorStore()
        self.connectors: list[BaseConnector] = [
            GoogleDriveConnector(),
            SlackHistoryConnector(),
            GmailConnector(),
            QuickBooksConnector(),
            FrappeConnector(),
            EncircleConnector(),
        ]
        self._last_sync: dict[str, float] = {}

    async def full_sync(self, sources: Optional[list[str]] = None) -> dict:
        """Run full sync for specified sources (or all)."""
        results = {}

        for connector in self.connectors:
            if sources and connector.source_name not in sources:
                continue

            logger.info("starting_sync", source=connector.source_name)
            count = await self._sync_connector(connector, incremental=False)
            results[connector.source_name] = count
            self._last_sync[connector.source_name] = datetime.now().timestamp()

        return results

    async def incremental_sync(self, sources: Optional[list[str]] = None) -> dict:
        """Run incremental sync for specified sources."""
        results = {}

        for connector in self.connectors:
            if sources and connector.source_name not in sources:
                continue

            last_sync = self._last_sync.get(connector.source_name, 0)
            if last_sync == 0:
                logger.info("no_previous_sync_running_full", source=connector.source_name)
                count = await self._sync_connector(connector, incremental=False)
            else:
                count = await self._sync_connector(
                    connector, incremental=True, since=last_sync
                )

            results[connector.source_name] = count
            self._last_sync[connector.source_name] = datetime.now().timestamp()

        return results

    async def _sync_connector(
        self,
        connector: BaseConnector,
        incremental: bool = False,
        since: float = None,
    ) -> int:
        """Sync a single connector."""
        batch: list[MemoryDocument] = []
        batch_size = 50
        total_count = 0

        try:
            if incremental and since:
                doc_iter = connector.fetch_incremental(since)
            else:
                doc_iter = connector.fetch_documents()

            async for doc in doc_iter:
                batch.append(doc)

                if len(batch) >= batch_size:
                    await self._process_batch(batch)
                    total_count += len(batch)
                    batch = []

            if batch:
                await self._process_batch(batch)
                total_count += len(batch)

            logger.info(
                "sync_complete",
                source=connector.source_name,
                documents=total_count,
            )

        except Exception as e:
            logger.error(
                "sync_failed",
                source=connector.source_name,
                error=str(e),
            )

        return total_count

    async def _process_batch(self, documents: list[MemoryDocument]):
        """Generate embeddings and upsert a batch of documents."""
        texts = [doc.content for doc in documents]
        embeddings = await self.embeddings.embed_batch(texts)

        for doc, embedding in zip(documents, embeddings):
            doc.embedding = embedding

        await self.vector_store.upsert(documents)


async def run_full_ingestion():
    """CLI entry point for full ingestion."""
    orchestrator = IngestionOrchestrator()
    results = await orchestrator.full_sync()

    print("\nIngestion Complete:")
    print("-" * 40)
    for source, count in results.items():
        print(f"  {source}: {count} documents")
    print("-" * 40)
    total = sum(results.values())
    print(f"  Total: {total} documents")


if __name__ == "__main__":
    asyncio.run(run_full_ingestion())
