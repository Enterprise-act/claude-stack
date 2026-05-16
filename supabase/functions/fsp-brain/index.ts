import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import OpenAI from "npm:openai@4";

// ── env ───────────────────────────────────────────────────────────────────────
const BRAIN_TOKEN         = Deno.env.get("FSP_BRAIN_TOKEN")          ?? "";
const SUPABASE_URL        = Deno.env.get("SUPABASE_URL")             ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const OPENAI_KEY          = Deno.env.get("OPENAI_API_KEY")           ?? "";

// ── helpers ───────────────────────────────────────────────────────────────────
async function sha256hex(text: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, "0")).join("");
}

function db(): SupabaseClient {
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { persistSession: false },
  });
}

async function embed(text: string): Promise<number[]> {
  const openai = new OpenAI({ apiKey: OPENAI_KEY });
  const res = await openai.embeddings.create({
    model: "text-embedding-3-small",
    input: text.slice(0, 8000),
  });
  return res.data[0].embedding;
}

function slugify(s: string): string {
  return s.toLowerCase().replace(/\s+/g, "-").replace(/[^a-z0-9-]/g, "");
}

async function resolveClient(sb: SupabaseClient, name: string): Promise<string | undefined> {
  const { data } = await sb
    .from("fsp_clients")
    .select("id")
    .or(`slug.eq.${slugify(name)},name.ilike.%${name}%`)
    .limit(1);
  return data?.[0]?.id;
}

async function resolveProject(
  sb: SupabaseClient,
  clientId: string,
  name: string
): Promise<string | undefined> {
  const { data } = await sb
    .from("fsp_projects")
    .select("id")
    .eq("client_id", clientId)
    .ilike("name", `%${name}%`)
    .limit(1);
  return data?.[0]?.id;
}

// ── tool implementations ──────────────────────────────────────────────────────
async function fsp_get_client_context(args: Record<string, unknown>) {
  const sb   = db();
  const name = String(args.client_name ?? "");
  const { data: clients } = await sb
    .from("fsp_clients")
    .select("*")
    .or(`slug.eq.${slugify(name)},name.ilike.%${name}%`)
    .limit(1);
  if (!clients?.length)
    return { error: `No client found: "${name}". Try fsp_recall to search broadly.` };
  const c = clients[0];
  const [pRes, mRes, aRes, dRes] = await Promise.all([
    sb.from("fsp_projects").select("*").eq("client_id", c.id).order("created_at", { ascending: false }).limit(10),
    sb.from("fsp_memories").select("id,type,content,created_by,source,created_at").eq("client_id", c.id).order("created_at", { ascending: false }).limit(10),
    sb.from("fsp_activity_log").select("staff_name,session_summary,created_at").eq("client_id", c.id).order("created_at", { ascending: false }).limit(5),
    sb.from("fsp_decisions").select("title,content,category,decided_by,created_at").eq("status", "active").order("created_at", { ascending: false }).limit(5),
  ]);
  return {
    client: { name: c.name, industry: c.industry, status: c.status, notes: c.notes, since: c.created_at },
    active_projects:    pRes.data ?? [],
    recent_memories:    mRes.data ?? [],
    recent_activity:    aRes.data ?? [],
    relevant_decisions: dRes.data ?? [],
  };
}

async function fsp_recall(args: Record<string, unknown>) {
  const sb         = db();
  const query      = String(args.query ?? "");
  const type       = args.type        ? String(args.type)        : null;
  const clientName = args.client_name ? String(args.client_name) : null;
  const limit      = Number(args.limit ?? 8);

  let clientId: string | undefined;
  if (clientName) clientId = await resolveClient(sb, clientName);

  if (OPENAI_KEY) {
    const vector = await embed(query);
    const { data, error } = await sb.rpc("match_fsp_memories", {
      query_embedding:  vector,
      match_threshold:  0.3,
      match_count:      limit,
      filter_type:      type,
      filter_client_id: clientId ?? null,
    });
    if (!error) return { results: data ?? [], search_mode: "semantic" };
  }

  // text fallback
  let q = sb
    .from("fsp_memories")
    .select("id,type,content,created_by,client_id,source,created_at")
    .ilike("content", `%${query}%`)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (type)     q = q.eq("type", type);
  if (clientId) q = q.eq("client_id", clientId);
  const { data: fallback } = await q;
  return { results: fallback ?? [], search_mode: "text_fallback" };
}

async function fsp_remember(args: Record<string, unknown>) {
  const sb        = db();
  const content   = String(args.content ?? "");
  const staffName = String(args._staff_name ?? args.created_by ?? args.staff_name ?? "unknown");

  let clientId: string | undefined;
  if (args.client_name) clientId = await resolveClient(sb, String(args.client_name));
  let projectId: string | undefined;
  if (args.project_name && clientId)
    projectId = await resolveProject(sb, clientId, String(args.project_name));

  const embedding = OPENAI_KEY ? await embed(content) : null;

  const { data, error } = await sb
    .from("fsp_memories")
    .insert({
      type:       String(args.type ?? "client_note"),
      content,
      ...(embedding ? { embedding } : {}),
      client_id:  clientId  ?? null,
      project_id: projectId ?? null,
      created_by: staffName,
      source:     String(args.source ?? "claude_session"),
      tags:       (args.tags as string[]) ?? [],
    })
    .select("id,type,created_at")
    .single();

  if (error) return { error: error.message };
  return { stored: true, id: data.id, type: data.type, client_id: clientId ?? null, created_at: data.created_at };
}

async function fsp_log_activity(args: Record<string, unknown>) {
  const sb        = db();
  const staffName = String(args._staff_name ?? args.staff_name ?? "unknown");
  const summary   = String(args.summary ?? args.session_summary ?? "");

  let clientId: string | undefined;
  if (args.client_name) clientId = await resolveClient(sb, String(args.client_name));
  let projectId: string | undefined;
  if (args.project_name && clientId)
    projectId = await resolveProject(sb, clientId, String(args.project_name));

  const { data, error } = await sb
    .from("fsp_activity_log")
    .insert({
      staff_name:      staffName,
      session_summary: summary,
      client_id:       clientId  ?? null,
      project_id:      projectId ?? null,
      duration_mins:   args.duration_mins ? Number(args.duration_mins) : null,
    })
    .select("id,created_at")
    .single();

  if (error) return { error: error.message };
  return { logged: true, id: data.id, staff_name: staffName, created_at: data.created_at };
}

async function fsp_list_active_projects(args: Record<string, unknown>) {
  const sb     = db();
  const status = String(args.status ?? "active");
  let q = sb
    .from("fsp_projects")
    .select("id,name,status,owner_name,due_date,created_at,fsp_clients(name,slug,industry)")
    .order("created_at", { ascending: false });
  if (status !== "all") q = q.eq("status", status);
  const { data, error } = await q;
  if (error) return { error: error.message };
  return { count: data?.length ?? 0, projects: data ?? [] };
}

async function fsp_search_decisions(args: Record<string, unknown>) {
  const sb    = db();
  const topic = String(args.topic ?? "");
  let q = sb
    .from("fsp_decisions")
    .select("*")
    .eq("status", "active")
    .order("created_at", { ascending: false })
    .limit(10);
  if (args.category) q = q.eq("category", String(args.category));

  const [contentRes, titleRes] = await Promise.all([
    q.ilike("content", `%${topic}%`),
    sb.from("fsp_decisions").select("*").eq("status", "active").ilike("title", `%${topic}%`).limit(5),
  ]);
  const combined = [...(contentRes.data ?? []), ...(titleRes.data ?? [])];
  const unique   = Array.from(new Map(combined.map((d) => [d.id, d])).values());
  return { count: unique.length, decisions: unique };
}

async function fsp_get_team_activity(args: Record<string, unknown>) {
  const sb    = db();
  const days  = Number(args.days ?? 7);
  const since = new Date(Date.now() - days * 86_400_000).toISOString();

  let q = sb
    .from("fsp_activity_log")
    .select("staff_name,session_summary,duration_mins,created_at,fsp_clients(name,slug),fsp_projects(name)")
    .gte("created_at", since)
    .order("created_at", { ascending: false });
  if (args.staff_name) q = q.ilike("staff_name", `%${args.staff_name}%`);

  const { data, error } = await q;
  if (error) return { error: error.message };

  const byStaff: Record<string, unknown[]> = {};
  for (const e of (data ?? [])) {
    if (!byStaff[e.staff_name]) byStaff[e.staff_name] = [];
    byStaff[e.staff_name].push(e);
  }
  return { period_days: days, total_sessions: data?.length ?? 0, by_staff: byStaff };
}

// ── tool registry ─────────────────────────────────────────────────────────────
const TOOLS = [
  {
    name: "fsp_get_client_context",
    description: "Get full context on a client — call before starting any client work. Returns active projects, recent communications, decisions, and activity.",
    inputSchema: {
      type: "object",
      properties: { client_name: { type: "string", description: "Client name or slug" } },
      required: ["client_name"],
    },
  },
  {
    name: "fsp_recall",
    description: "Semantic search across all shared memories — research, decisions, outputs, communications. Use natural language.",
    inputSchema: {
      type: "object",
      properties: {
        query:       { type: "string" },
        type:        { type: "string", enum: ["decision","research","output","communication","sop","client_note","task_state"] },
        client_name: { type: "string" },
        limit:       { type: "number" },
      },
      required: ["query"],
    },
  },
  {
    name: "fsp_remember",
    description: "Store a memory, decision, research finding, or client note in the shared brain.",
    inputSchema: {
      type: "object",
      properties: {
        content:      { type: "string" },
        type:         { type: "string", enum: ["decision","research","output","communication","sop","client_note","task_state"] },
        client_name:  { type: "string" },
        project_name: { type: "string" },
        tags:         { type: "array", items: { type: "string" } },
        source:       { type: "string" },
        created_by:   { type: "string" },
      },
      required: ["content", "type"],
    },
  },
  {
    name: "fsp_log_activity",
    description: "Log what was accomplished in a session. Called by the session-end hook, or manually.",
    inputSchema: {
      type: "object",
      properties: {
        summary:       { type: "string" },
        client_name:   { type: "string" },
        project_name:  { type: "string" },
        duration_mins: { type: "number" },
        staff_name:    { type: "string" },
      },
      required: ["summary"],
    },
  },
  {
    name: "fsp_list_active_projects",
    description: "See all in-progress projects across the team with owners and clients.",
    inputSchema: {
      type: "object",
      properties: {
        status: { type: "string", enum: ["active","completed","paused","all"], default: "active" },
      },
    },
  },
  {
    name: "fsp_search_decisions",
    description: "Search company decisions and SOPs before making any judgment call on pricing, process, or vendors.",
    inputSchema: {
      type: "object",
      properties: {
        topic:    { type: "string" },
        category: { type: "string", enum: ["pricing","process","client","vendor","product","hr"] },
      },
      required: ["topic"],
    },
  },
  {
    name: "fsp_get_team_activity",
    description: "See what the team has been working on recently, grouped by staff member.",
    inputSchema: {
      type: "object",
      properties: {
        days:       { type: "number", default: 7 },
        staff_name: { type: "string" },
      },
    },
  },
];

const HANDLERS: Record<string, (a: Record<string, unknown>) => Promise<unknown>> = {
  fsp_get_client_context,
  fsp_recall,
  fsp_remember,
  fsp_log_activity,
  fsp_list_active_projects,
  fsp_search_decisions,
  fsp_get_team_activity,
};

// ── MCP JSON-RPC 2.0 ──────────────────────────────────────────────────────────
async function handleMcp(body: unknown, staffName?: string): Promise<unknown> {
  const req = body as { jsonrpc: string; id?: unknown; method: string; params?: unknown };
  const id  = req.id ?? null;

  switch (req.method) {
    case "initialize":
      return {
        jsonrpc: "2.0", id,
        result: {
          protocolVersion: "2024-11-05",
          capabilities: { tools: { listChanged: false } },
          serverInfo: { name: "fsp-brain", version: "1.0.0" },
        },
      };

    case "notifications/initialized":
      return null;

    case "tools/list":
      return { jsonrpc: "2.0", id, result: { tools: TOOLS } };

    case "tools/call": {
      const p       = req.params as { name: string; arguments?: Record<string, unknown> };
      const handler = HANDLERS[p.name];
      if (!handler)
        return { jsonrpc: "2.0", id, error: { code: -32601, message: `Unknown tool: ${p.name}` } };
      try {
        const args = staffName
          ? { ...p.arguments ?? {}, _staff_name: staffName }
          : p.arguments ?? {};
        const result = await handler(args);
        return { jsonrpc: "2.0", id, result: { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] } };
      } catch (e) {
        return { jsonrpc: "2.0", id, error: { code: -32603, message: String(e) } };
      }
    }

    default:
      return { jsonrpc: "2.0", id, error: { code: -32601, message: `Unknown method: ${req.method}` } };
  }
}

// ── HTTP handler ──────────────────────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  const url      = new URL(req.url);
  const lastPart = url.pathname.split("/").at(-1) ?? "";

  // health
  if (req.method === "GET")
    return Response.json({ status: "ok", service: "fsp-brain", version: "1.0.0" });

  if (req.method !== "POST")
    return new Response("Method Not Allowed", { status: 405 });

  // ── auth + rate limiting ──────────────────────────────────────────────────
  const rawToken = (req.headers.get("authorization") ?? "").replace(/^Bearer /, "").trim();
  if (!rawToken) return Response.json({ error: "Unauthorized" }, { status: 401 });

  // Compatibility: existing staff using the shared BRAIN_TOKEN keep working
  // during the per-staff token rollout. Remove once all staff have personal tokens.
  let staffName: string;
  if (BRAIN_TOKEN && rawToken === BRAIN_TOKEN) {
    staffName = Deno.env.get("FSP_STAFF_NAME") ?? "legacy";
  } else {
    const hash      = await sha256hex(rawToken);
    const windowMin = Math.floor(Date.now() / 60_000);
    const { data: auth } = await db().rpc("fsp_authorize_request", {
      p_token_hash: hash,
      p_window_min: windowMin,
      p_limit: 60,
    });
    if (!auth?.authorized) {
      const status = auth?.reason === "rate_limited" ? 429 : 401;
      return Response.json({ error: auth?.reason ?? "Unauthorized" }, { status });
    }
    staffName = auth.staff_name;
    if (Math.random() < 0.05) db().rpc("fsp_prune_rate_limit").then(() => {});
  }

  const bodyText = await req.text();
  let body: unknown;
  try { body = JSON.parse(bodyText); }
  catch { return Response.json({ error: "Invalid JSON" }, { status: 400 }); }

  // REST /log for shell hook
  if (lastPart === "log") {
    const b = body as Record<string, unknown>;
    const result = await fsp_log_activity({ ...b, _staff_name: staffName });
    return Response.json(result);
  }

  // MCP JSON-RPC
  const result = await handleMcp(body, staffName);
  if (result === null) return new Response(null, { status: 204 });
  return Response.json(result);
});
