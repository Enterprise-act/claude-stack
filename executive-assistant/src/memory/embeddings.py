"""Embedding generation using Voyage AI."""

import hashlib
from typing import Optional

import httpx
import structlog

from ..config import get_settings

logger = structlog.get_logger()

VOYAGE_EMBED_URL = "https://api.voyageai.com/v1/embeddings"
EMBEDDING_MODEL = "voyage-3"  # Best for enterprise retrieval
EMBEDDING_DIMENSION = 1024


class EmbeddingService:
    """Generate embeddings using Voyage AI."""

    def __init__(self, api_key: Optional[str] = None):
        settings = get_settings()
        self.api_key = api_key or settings.voyage_api_key
        self._cache: dict[str, list[float]] = {}

    def _cache_key(self, text: str) -> str:
        return hashlib.sha256(text.encode()).hexdigest()[:16]

    async def embed(self, text: str) -> list[float]:
        """Generate embedding for a single text."""
        cache_key = self._cache_key(text)
        if cache_key in self._cache:
            return self._cache[cache_key]

        embeddings = await self.embed_batch([text])
        return embeddings[0]

    async def embed_batch(self, texts: list[str]) -> list[list[float]]:
        """Generate embeddings for multiple texts."""
        if not texts:
            return []

        async with httpx.AsyncClient() as client:
            response = await client.post(
                VOYAGE_EMBED_URL,
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "input": texts,
                    "model": EMBEDDING_MODEL,
                    "input_type": "document",
                },
                timeout=60.0,
            )
            response.raise_for_status()
            data = response.json()

        embeddings = [item["embedding"] for item in data["data"]]

        for text, embedding in zip(texts, embeddings):
            cache_key = self._cache_key(text)
            self._cache[cache_key] = embedding

        logger.info("generated_embeddings", count=len(texts))
        return embeddings

    async def embed_query(self, query: str) -> list[float]:
        """Generate embedding for a search query (uses different input type)."""
        async with httpx.AsyncClient() as client:
            response = await client.post(
                VOYAGE_EMBED_URL,
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "input": [query],
                    "model": EMBEDDING_MODEL,
                    "input_type": "query",
                },
                timeout=30.0,
            )
            response.raise_for_status()
            data = response.json()

        return data["data"][0]["embedding"]
