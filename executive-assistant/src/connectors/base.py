"""Base connector interface."""

from abc import ABC, abstractmethod
from typing import AsyncIterator

from ..memory.vector_store import MemoryDocument


class BaseConnector(ABC):
    """Base class for data source connectors."""

    @property
    @abstractmethod
    def source_name(self) -> str:
        """Return the source identifier (e.g., 'slack', 'gdrive')."""
        pass

    @abstractmethod
    async def fetch_documents(self) -> AsyncIterator[MemoryDocument]:
        """Fetch documents from the source for ingestion."""
        pass

    @abstractmethod
    async def fetch_incremental(self, since_timestamp: float) -> AsyncIterator[MemoryDocument]:
        """Fetch only documents modified since the given timestamp."""
        pass
