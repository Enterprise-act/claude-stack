# FSP Executive Assistant

AI-powered enterprise assistant for Full Service Pros. When @mentioned in Slack,
it answers questions and executes tasks using your company's collective knowledge.

## Architecture

```
Slack @mention → Webhook → Intent Router → Memory Retrieval → Task Execution → Response
                              │                   │                 │
                              ▼                   ▼                 ▼
                         Claude API          Vector DB         MCP Tools
                                                │
                    ┌───────────────────────────┼───────────────────────────┐
                    ▼           ▼         ▼           ▼           ▼         ▼
                 Frappe    Google Drive  Slack    Gmail      QuickBooks  Encircle
```

## Data Sources

| Source | Type | Status |
|--------|------|--------|
| Slack | Conversations, decisions, announcements | Ready |
| Google Drive | Documents, SOPs, meeting notes | Ready |
| Gmail | Client communications, threads | Ready |
| QuickBooks | Financial data, invoices, clients | Ready |
| Frappe | ERP/CRM data | Pending connection |
| Encircle | Property documentation, inspections | Ready |

## Quick Start

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Configure environment
cp config/.env.example config/.env
# Edit config/.env with your API keys

# 3. Initialize the vector database
python -m src.memory.init_db

# 4. Start the assistant
python -m src.api.server
```

## Components

### `/src/connectors/` - Data Source Connectors
- `google_drive.py` - Google Drive/Docs ingestion
- `slack_history.py` - Slack channel/thread history
- `gmail.py` - Gmail thread ingestion (multi-account)
- `quickbooks.py` - QuickBooks client/financial data
- `frappe.py` - Frappe ERP/CRM connector
- `encircle.py` - Encircle property documentation

### `/src/memory/` - Enterprise Memory
- `vector_store.py` - Vector database operations (Qdrant)
- `embeddings.py` - Text embedding generation
- `retrieval.py` - Semantic search and context retrieval
- `ingestion.py` - Document chunking and indexing

### `/src/slack/` - Slack Integration
- `bot.py` - Slack bot event handler
- `commands.py` - Slash command handlers
- `threading.py` - Thread-aware conversation management

### `/src/tasks/` - Task Execution
- `scheduler.py` - Google Calendar integration
- `email.py` - Gmail send/draft
- `workflows.py` - n8n workflow triggers

### `/src/api/` - API Server
- `server.py` - FastAPI application
- `webhooks.py` - Slack webhook handlers
- `health.py` - Health check endpoints

## Environment Variables

See `config/.env.example` for all required variables.

## Deployment

Designed for horizontal scalability:
- **Message Queue**: Redis for async Slack message processing
- **Vector DB**: Qdrant (self-hosted or cloud)
- **API Server**: Docker containers behind load balancer
- **Workers**: Celery workers for background tasks

```bash
# Docker deployment
docker-compose up -d

# Or Kubernetes
kubectl apply -f k8s/
```
