"""Celery worker for background tasks."""

from celery import Celery
from celery.schedules import crontab

from .config import get_settings

settings = get_settings()

app = Celery(
    "executive-assistant",
    broker=settings.redis_url,
    backend=settings.redis_url,
)

app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
)

app.conf.beat_schedule = {
    "incremental-sync-hourly": {
        "task": "src.worker.incremental_sync",
        "schedule": crontab(minute=0),  # Every hour
    },
    "full-sync-daily": {
        "task": "src.worker.full_sync",
        "schedule": crontab(hour=2, minute=0),  # Daily at 2 AM
    },
}


@app.task
def incremental_sync(sources: list[str] = None):
    """Run incremental sync of enterprise data."""
    import asyncio
    from .memory.ingestion import IngestionOrchestrator

    orchestrator = IngestionOrchestrator()
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    try:
        results = loop.run_until_complete(orchestrator.incremental_sync(sources))
        return {"status": "success", "results": results}
    finally:
        loop.close()


@app.task
def full_sync(sources: list[str] = None):
    """Run full sync of enterprise data."""
    import asyncio
    from .memory.ingestion import IngestionOrchestrator

    orchestrator = IngestionOrchestrator()
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    try:
        results = loop.run_until_complete(orchestrator.full_sync(sources))
        return {"status": "success", "results": results}
    finally:
        loop.close()
