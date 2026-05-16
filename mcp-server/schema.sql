-- FSP Brain — Supabase Schema
-- Tables use fsp_ prefix to avoid conflicts with other tables in the project.
-- Run this once in your Supabase project SQL editor, or apply via Supabase MCP.

create extension if not exists vector;

-- ── clients ───────────────────────────────────────────────────────────────────

create table if not exists fsp_clients (
  id         uuid        primary key default gen_random_uuid(),
  name       text        not null,
  slug       text        unique not null,
  industry   text,
  status     text        not null default 'active',
  notes      text,
  created_at timestamptz not null default now()
);

-- ── projects ──────────────────────────────────────────────────────────────────

create table if not exists fsp_projects (
  id         uuid        primary key default gen_random_uuid(),
  client_id  uuid        references fsp_clients on delete cascade,
  name       text        not null,
  status     text        not null default 'active',
  owner_name text,
  due_date   date,
  created_at timestamptz not null default now()
);

-- ── memories ──────────────────────────────────────────────────────────────────

create table if not exists fsp_memories (
  id         uuid        primary key default gen_random_uuid(),
  type       text        not null,
  content    text        not null,
  embedding  vector(1536),
  client_id  uuid        references fsp_clients  on delete set null,
  project_id uuid        references fsp_projects on delete set null,
  created_by text        not null,
  source     text,
  tags       text[]      default '{}',
  created_at timestamptz not null default now()
);

create index if not exists fsp_memories_embedding_idx
  on fsp_memories using ivfflat (embedding vector_cosine_ops)
  with (lists = 100);

create index if not exists fsp_memories_client_idx  on fsp_memories (client_id);
create index if not exists fsp_memories_type_idx    on fsp_memories (type);
create index if not exists fsp_memories_created_idx on fsp_memories (created_at desc);

-- ── activity log ──────────────────────────────────────────────────────────────

create table if not exists fsp_activity_log (
  id              uuid        primary key default gen_random_uuid(),
  staff_name      text        not null,
  session_summary text        not null,
  client_id       uuid        references fsp_clients  on delete set null,
  project_id      uuid        references fsp_projects on delete set null,
  duration_mins   int,
  created_at      timestamptz not null default now()
);

create index if not exists fsp_activity_log_staff_idx   on fsp_activity_log (staff_name);
create index if not exists fsp_activity_log_client_idx  on fsp_activity_log (client_id);
create index if not exists fsp_activity_log_created_idx on fsp_activity_log (created_at desc);

-- ── decisions & SOPs ──────────────────────────────────────────────────────────

create table if not exists fsp_decisions (
  id         uuid        primary key default gen_random_uuid(),
  title      text        not null,
  content    text        not null,
  category   text,
  status     text        not null default 'active',
  decided_by text,
  created_at timestamptz not null default now()
);

-- ── RLS ───────────────────────────────────────────────────────────────────────
-- Service role key bypasses RLS automatically. Anon key is read-only.

alter table fsp_clients      enable row level security;
alter table fsp_projects     enable row level security;
alter table fsp_memories     enable row level security;
alter table fsp_activity_log enable row level security;
alter table fsp_decisions    enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where tablename = 'fsp_clients'      and policyname = 'anon_read_fsp_clients')   then create policy "anon_read_fsp_clients"   on fsp_clients      for select using (true); end if;
  if not exists (select 1 from pg_policies where tablename = 'fsp_projects'     and policyname = 'anon_read_fsp_projects')  then create policy "anon_read_fsp_projects"  on fsp_projects     for select using (true); end if;
  if not exists (select 1 from pg_policies where tablename = 'fsp_memories'     and policyname = 'anon_read_fsp_memories')  then create policy "anon_read_fsp_memories"  on fsp_memories     for select using (true); end if;
  if not exists (select 1 from pg_policies where tablename = 'fsp_activity_log' and policyname = 'anon_read_fsp_activity')  then create policy "anon_read_fsp_activity"  on fsp_activity_log for select using (true); end if;
  if not exists (select 1 from pg_policies where tablename = 'fsp_decisions'    and policyname = 'anon_read_fsp_decisions') then create policy "anon_read_fsp_decisions" on fsp_decisions     for select using (true); end if;
end $$;

-- ── pgvector similarity search RPC ───────────────────────────────────────────

create or replace function match_fsp_memories(
  query_embedding  vector(1536),
  match_threshold  float   default 0.3,
  match_count      int     default 8,
  filter_type      text    default null,
  filter_client_id uuid    default null
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
language sql stable as $$
  select
    m.id, m.type, m.content, m.created_by, m.source,
    m.client_id, m.created_at,
    1 - (m.embedding <=> query_embedding) as similarity
  from fsp_memories m
  where
    (filter_type      is null or m.type      = filter_type)
    and (filter_client_id is null or m.client_id = filter_client_id)
    and 1 - (m.embedding <=> query_embedding) > match_threshold
  order by m.embedding <=> query_embedding
  limit match_count;
$$;

-- ── v2: Per-staff auth + rate limiting ───────────────────────────────────────

create table if not exists fsp_staff_tokens (
  id          uuid    primary key default gen_random_uuid(),
  token_hash  text    unique not null,
  staff_name  text    not null,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);
alter table fsp_staff_tokens enable row level security;

create table if not exists fsp_rate_limit (
  token_hash  text    not null,
  window_min  bigint  not null,
  req_count   int     not null default 1,
  primary key (token_hash, window_min)
);
alter table fsp_rate_limit enable row level security;

create or replace function fsp_authorize_request(
  p_token_hash text,
  p_window_min bigint,
  p_limit      int default 60
) returns jsonb language plpgsql security definer as $$
declare
  v_staff_name text;
  v_count      int;
begin
  select staff_name into v_staff_name
  from   fsp_staff_tokens
  where  token_hash = p_token_hash and active = true;

  if v_staff_name is null then
    return jsonb_build_object('authorized', false, 'reason', 'invalid_token');
  end if;

  insert into fsp_rate_limit (token_hash, window_min, req_count)
  values (p_token_hash, p_window_min, 1)
  on conflict (token_hash, window_min)
  do update set req_count = fsp_rate_limit.req_count + 1
  returning req_count into v_count;

  if v_count > p_limit then
    return jsonb_build_object(
      'authorized', false, 'reason', 'rate_limited', 'count', v_count
    );
  end if;

  return jsonb_build_object(
    'authorized', true, 'staff_name', v_staff_name, 'count', v_count
  );
end;
$$;

create or replace function fsp_prune_rate_limit() returns void language sql as $$
  delete from fsp_rate_limit
  where window_min < floor(extract(epoch from now()) / 60) - 10;
$$;
