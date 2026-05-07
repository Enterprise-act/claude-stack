"""Memory retrieval - semantic search across enterprise knowledge."""

from dataclasses import dataclass
from typing import Optional

import structlog

from .embeddings import EmbeddingService
from .vector_store import VectorStore, SearchResult

logger = structlog.get_logger()


@dataclass
class RetrievalResult:
    """Context retrieved from enterprise memory."""

    query: str
    results: list[SearchResult]
    context_text: str  # Formatted for Claude prompt


class MemoryRetriever:
    """Retrieve relevant context from enterprise memory."""

    def __init__(self):
        self.embeddings = EmbeddingService()
        self.vector_store = VectorStore()

    async def retrieve(
        self,
        query: str,
        limit: int = 8,
        source_filter: Optional[str] = None,
        min_score: float = 0.5,
    ) -> RetrievalResult:
        """Retrieve relevant documents for a query."""
        query_embedding = await self.embeddings.embed_query(query)

        results = await self.vector_store.search(
            query_embedding=query_embedding,
            limit=limit,
            source_filter=source_filter,
        )

        filtered = [r for r in results if r.score >= min_score]

        context_text = self._format_context(filtered)

        logger.info(
            "memory_retrieved",
            query=query[:100],
            total_results=len(results),
            filtered_results=len(filtered),
        )

        return RetrievalResult(
            query=query,
            results=filtered,
            context_text=context_text,
        )

    def _format_context(self, results: list[SearchResult]) -> str:
        """Format search results into context for Claude."""
        if not results:
            return "No relevant information found in enterprise memory."

        sections = []
        for i, result in enumerate(results, 1):
            doc = result.document
            source_label = self._source_label(doc.source)

            section = f"[{i}] {source_label}\n"

            if doc.metadata.get("title"):
                section += f"Title: {doc.metadata['title']}\n"
            if doc.metadata.get("author"):
                section += f"Author: {doc.metadata['author']}\n"
            if doc.metadata.get("date"):
                section += f"Date: {doc.metadata['date']}\n"

            section += f"\n{doc.content}\n"
            section += f"(Relevance: {result.score:.0%})"

            sections.append(section)

        return "\n\n---\n\n".join(sections)

    def _source_label(self, source: str) -> str:
        """Human-readable source label."""
        labels = {
            "slack": "Slack Message",
            "gdrive": "Google Drive Document",
            "gmail": "Email",
            "quickbooks": "QuickBooks Record",
            "frappe": "Frappe CRM/ERP",
            "encircle": "Encircle Property Doc",
        }
        return labels.get(source, source.title())

    async def retrieve_multi_source(
        self,
        query: str,
        sources: list[str],
        limit_per_source: int = 3,
    ) -> RetrievalResult:
        """Retrieve from multiple specific sources."""
        all_results = []

        for source in sources:
            results = await self.retrieve(
                query=query,
                limit=limit_per_source,
                source_filter=source,
            )
            all_results.extend(results.results)

        all_results.sort(key=lambda r: r.score, reverse=True)

        context_text = self._format_context(all_results)

        return RetrievalResult(
            query=query,
            results=all_results,
            context_text=context_text,
        )
