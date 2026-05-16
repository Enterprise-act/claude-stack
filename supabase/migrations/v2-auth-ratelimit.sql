-- FSP Brain v2 — Per-staff auth + rate limiting
-- Apply once to the live project via Supabase MCP apply_migration.
-- Also appended to mcp-server/schema.sql for fresh installs.

-- ── Per-staff tokens ──────────────────────────────────────────────────────────
-- Mark manages rows here. Staff never access this table.
-- Store SHA-256(raw_token) only — never store plaintext tokens.

create table if not exists fsp_staff_tokens (
  id          uuid    primary key default gen_random_uuid(),
  token_hash  text    unique not null,
  staff_name  text    not null,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

alter table fsp_staff_tokens enable row level security;
-- No anon or authenticated policies — service role bypasses RLS.

-- ── Rate-limit windows ────────────────────────────────────────────────────────
-- One row per (token, 1-minute window). Pruned by fsp_prune_rate_limit().

create table if not exists fsp_rate_limit (
  token_hash  text    not null,
  window_min  bigint  not null,
  req_count   int     not null default 1,
  primary key (token_hash, window_min)
);

alter table fsp_rate_limit enable row level security;
-- No anon or authenticated policies — service role bypasses RLS.

-- ── Combined auth + rate-limit RPC (single round trip per request) ────────────

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

-- ── Rate-limit pruner (called ~5% of requests from the Edge Function) ─────────

create or replace function fsp_prune_rate_limit() returns void language sql as $$
  delete from fsp_rate_limit
  where window_min < floor(extract(epoch from now()) / 60) - 10;
$$;
