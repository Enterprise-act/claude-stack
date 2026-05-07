"""Vector database operations using Qdrant."""

from dataclasses import dataclass
from typing import Any, Optional
from uuid import uuid4

import structlog
from qdrant_client import QdrantClient
from qdrant_client.models import (
    Distance,
    PointStruct,
    VectorParams,
    Filter,
    FieldCondition,
    MatchValue,
)

from ..config import get_settings
from .embeddings import EMBEDDING_DIMENSION

logger = structlog.get_logger()

COLLECTION_NAME = "fsp_enterprise_memory"


@dataclass
class MemoryDocument:
    """A document stored in enterprise memory."""

    id: str
    content: str
    source: str  # slack, gdrive, gmail, quickbooks, frappe, encircle
    source_id: str  # Original ID from source system
    metadata: dict[str, Any]
    embedding: Optional[list[float]] = None


@dataclass
class SearchResult:
    """A search result from memory."""

    document: MemoryDocument
    score: float


class VectorStore:
    """Vector database for enterprise memory."""

    def __init__(self):
        settings = get_settings()
        self.client = QdrantClient(
            url=settings.qdrant_url,
            api_key=settings.qdrant_api_key,
        )
        self._ensure_collection()

    def _ensure_collection(self):
        """Create collection if it doesn't exist."""
        collections = self.client.get_collections().collections
        exists = any(c.name == COLLECTION_NAME for c in collections)

        if not exists:
            self.client.create_collection(
                collection_name=COLLECTION_NAME,
                vectors_config=VectorParams(
                    size=EMBEDDING_DIMENSION,
                    distance=Distance.COSINE,
                ),
            )
            logger.info("created_collection", name=COLLECTION_NAME)

    async def upsert(self, documents: list[MemoryDocument]) -> int:
        """Insert or update documents in the vector store."""
        if not documents:
            return 0

        points = [
            PointStruct(
                id=doc.id,
                vector=doc.embedding,
                payload={
                    "content": doc.content,
                    "source": doc.source,
                    "source_id": doc.source_id,
                    **doc.metadata,
                },
            )
            for doc in documents
            if doc.embedding is not None
        ]

        self.client.upsert(collection_name=COLLECTION_NAME, points=points)
        logger.info("upserted_documents", count=len(points))
        return len(points)

    async def search(
        self,
        query_embedding: list[float],
        limit: int = 10,
        source_filter: Optional[str] = None,
    ) -> list[SearchResult]:
        """Search for similar documents."""
        filter_condition = None
        if source_filter:
            filter_condition = Filter(
                must=[
                    FieldCondition(
                        key="source",
                        match=MatchValue(value=source_filter),
                    )
                ]
            )

        results = self.client.search(
            collection_name=COLLECTION_NAME,
            query_vector=query_embedding,
            limit=limit,
            query_filter=filter_condition,
        )

        return [
            SearchResult(
                document=MemoryDocument(
                    id=str(hit.id),
                    content=hit.payload.get("content", ""),
                    source=hit.payload.get("source", "unknown"),
                    source_id=hit.payload.get("source_id", ""),
                    metadata={
                        k: v
                        for k, v in hit.payload.items()
                        if k not in ("content", "source", "source_id")
                    },
                ),
                score=hit.score,
            )
            for hit in results
        ]

    async def delete_by_source(self, source: str, source_id: str) -> bool:
        """Delete a document by its source and source_id."""
        self.client.delete(
            collection_name=COLLECTION_NAME,
            points_selector=Filter(
                must=[
                    FieldCondition(key="source", match=MatchValue(value=source)),
                    FieldCondition(key="source_id", match=MatchValue(value=source_id)),
                ]
            ),
        )
        return True

    async def get_stats(self) -> dict[str, Any]:
        """Get collection statistics."""
        info = self.client.get_collection(COLLECTION_NAME)
        return {
            "total_documents": info.points_count,
            "vectors_count": info.vectors_count,
            "status": info.status,
        }


def generate_doc_id(source: str, source_id: str) -> str:
    """Generate a deterministic document ID."""
    return str(uuid4())  # Could use hash for deduplication
