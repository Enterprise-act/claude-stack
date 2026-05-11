-- FSP Brain — Supabase Schema
-- Run this once in your Supabase project SQL editor.
-- Requires: pgvector extension (enabled below)

-- Enable vector similarity search
create extension if not exists vector;

-- ─────────────────────────────────────────────
-- Core entities
-- ─────────────────────────────────────────────

create table if not exists clients (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  slug        text unique not null,   -- lowercase-hyphenated, used as lookup key
  industry    text,
  status      text not null default 'active',  -- active | inactive | prospect
  notes       text,
  created_at  timestamptz not null default now()
);

create table if not exists projects (
  id          uuid primary key default gen_random_uuid(),
  client_id   uuid references clients on delete cascade,
  name        text not null,
  status      text not null default 'active',  -- active | completed | paused
  owner_name  text,
  due_date    date,
  created_at  timestamptz not null default now()
);

-- ─────────────────────────────────────────────
-- Shared knowledge base
-- ─────────────────────────────────────────────

create table if not exists memories (
  id          uuid primary key default gen_random_uuid(),
  type        text not null,
  -- decision | research | output | communication | sop | client_note | task_state
  content     text not null,
  embedding   vector(1536),           -- OpenAI text-embedding-3-small
  client_id   uuid references clients on delete set null,
  project_id  uuid references projects on delete set null,
  created_by  text not null,          -- FSP_STAFF_NAME env var
  source      text,                   -- slack | gmail | calendar | claude_session | manual
  tags        text[] default '{}',
  created_at  timestamptz not null default now()
);

-- IVFFlat index for approximate nearest-neighbour search
-- Tune lists = sqrt(row_count) when you have more data
create index if not exists memories_embedding_idx
  on memories using ivfflat (embedding vector_cosine_ops)
  with (lists = 100);

create index if not exists memories_client_idx on memories (client_id);
create index if not exists memories_type_idx   on memories (type);
create index if not exists memories_created_idx on memories (created_at desc);

-- ─────────────────────────────────────────────
-- Activity log — every session, every staff member
-- ─────────────────────────────────────────────

create table if not exists activity_log (
  id              uuid primary key default gen_random_uuid(),
  staff_name      text not null,
  session_summary text not null,
  client_id       uuid references clients on delete set null,
  project_id      uuid references projects on delete set null,
  duration_mins   int,
  created_at      timestamptz not null default now()
);

create index if not exists activity_log_staff_idx  on activity_log (staff_name);
create index if not exists activity_log_client_idx on activity_log (client_id);
create index if not exists activity_log_created_idx on activity_log (created_at desc);

-- ─────────────────────────────────────────────
-- Decisions & SOPs — queryable company rulebook
-- ─────────────────────────────────────────────

create table if not exists decisions (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  content     text not null,
  category    text,   -- pricing | process | client | vendor | product | hr
  status      text not null default 'active',  -- active | superseded | archived
  decided_by  text,
  created_at  timestamptz not null default now()
);

-- ─────────────────────────────────────────────
-- Row-level security (enable but keep permissive for service role)
-- ─────────────────────────────────────────────
-- The MCP server connects via service role key — bypasses RLS.
-- Enable RLS so the anon key (used by n8n read-only webhooks) is restricted.

alter table clients    enable row level security;
alter table projects   enable row level security;
alter table memories   enable row level security;
alter table activity_log enable row level security;
alter table decisions  enable row level security;

-- Allow all operations for service role (MCP server)
-- The service role key bypasses RLS automatically in Supabase.

-- Allow read-only for anon (n8n read operations, dashboards)
create policy "anon_read_clients"    on clients    for select using (true);
create policy "anon_read_projects"   on projects   for select using (true);
create policy "anon_read_memories"   on memories   for select using (true);
create policy "anon_read_activity"   on activity_log for select using (true);
create policy "anon_read_decisions"  on decisions  for select using (true);

-- ─────────────────────────────────────────────
-- pgvector similarity search RPC
-- Called by the recall tool for semantic search
-- ─────────────────────────────────────────────

create or replace function match_memories(
  query_embedding   vector(1536),
  match_threshold   float     default 0.3,
  match_count       int       default 8,
  filter_type       text      default null,
  filter_client_id  uuid      default null
)
returns table (
  id          uuid,
  type        text,
  content     text,
  created_by  text,
  source      text,
  client_id   uuid,
  created_at  timestamptz,
  similarity  float
)
language sql stable
as $$
  select
    m.id,
    m.type,
    m.content,
    m.created_by,
    m.source,
    m.client_id,
    m.created_at,
    1 - (m.embedding <=> query_embedding) as similarity
  from memories m
  where
    (filter_type is null or m.type = filter_type)
    and (filter_client_id is null or m.client_id = filter_client_id)
    and 1 - (m.embedding <=> query_embedding) > match_threshold
  order by m.embedding <=> query_embedding
  limit match_count;
$$;
