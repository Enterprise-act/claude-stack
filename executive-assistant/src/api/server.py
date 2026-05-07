"""FastAPI server for the Executive Assistant."""

import asyncio
from contextlib import asynccontextmanager

import structlog
import uvicorn
from fastapi import FastAPI, HTTPException, BackgroundTasks
from pydantic import BaseModel

from ..brain.assistant import ExecutiveAssistant
from ..brain.intents import Intent
from ..slack.bot import SlackBot
from ..tasks.calendar import CalendarTaskHandler
from ..tasks.email import EmailTaskHandler
from ..memory.ingestion import IngestionOrchestrator
from ..config import get_settings

logger = structlog.get_logger()

assistant: ExecutiveAssistant = None
slack_bot: SlackBot = None
ingestion: IngestionOrchestrator = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan - startup and shutdown."""
    global assistant, slack_bot, ingestion

    logger.info("starting_executive_assistant")

    assistant = ExecutiveAssistant()
    assistant.register_task_handler(Intent.TASK_CALENDAR, CalendarTaskHandler())
    assistant.register_task_handler(Intent.TASK_EMAIL, EmailTaskHandler())

    slack_bot = SlackBot(message_handler=assistant.handle_message)
    ingestion = IngestionOrchestrator()

    asyncio.create_task(slack_bot.start())

    logger.info("executive_assistant_ready")

    yield

    logger.info("shutting_down_executive_assistant")


def create_app() -> FastAPI:
    """Create the FastAPI application."""
    app = FastAPI(
        title="FSP Executive Assistant",
        description="AI-powered enterprise assistant for Full Service Pros",
        version="0.1.0",
        lifespan=lifespan,
    )

    @app.get("/health")
    async def health_check():
        """Health check endpoint."""
        return {"status": "healthy", "service": "executive-assistant"}

    @app.get("/memory/stats")
    async def memory_stats():
        """Get enterprise memory statistics."""
        from ..memory.vector_store import VectorStore

        store = VectorStore()
        stats = await store.get_stats()
        return stats

    class QueryRequest(BaseModel):
        query: str

    class QueryResponse(BaseModel):
        answer: str
        sources: list[dict] = []

    @app.post("/query", response_model=QueryResponse)
    async def query_assistant(request: QueryRequest):
        """Query the assistant directly (without Slack)."""
        if not assistant:
            raise HTTPException(status_code=503, detail="Assistant not initialized")

        answer = await assistant.direct_query(request.query)
        return QueryResponse(answer=answer, sources=[])

    class SyncRequest(BaseModel):
        sources: list[str] | None = None
        full: bool = False

    class SyncResponse(BaseModel):
        message: str
        results: dict[str, int]

    @app.post("/sync", response_model=SyncResponse)
    async def trigger_sync(request: SyncRequest, background_tasks: BackgroundTasks):
        """Trigger data sync from enterprise sources."""
        if not ingestion:
            raise HTTPException(status_code=503, detail="Ingestion not initialized")

        async def run_sync():
            if request.full:
                return await ingestion.full_sync(request.sources)
            else:
                return await ingestion.incremental_sync(request.sources)

        background_tasks.add_task(run_sync)

        return SyncResponse(
            message="Sync started in background",
            results={},
        )

    @app.post("/sync/now")
    async def sync_now(request: SyncRequest):
        """Run sync synchronously (blocking)."""
        if not ingestion:
            raise HTTPException(status_code=503, detail="Ingestion not initialized")

        if request.full:
            results = await ingestion.full_sync(request.sources)
        else:
            results = await ingestion.incremental_sync(request.sources)

        return SyncResponse(
            message="Sync complete",
            results=results,
        )

    return app


def main():
    """Run the server."""
    settings = get_settings()
    app = create_app()
    uvicorn.run(
        app,
        host=settings.api_host,
        port=settings.api_port,
        log_level=settings.log_level.lower(),
    )


if __name__ == "__main__":
    main()
