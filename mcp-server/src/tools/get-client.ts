import { z } from "zod";
import { db } from "../db.js";

export const schema = z.object({
  client_name: z.string().describe("Client name or slug (e.g. 'Acme Corp' or 'acme-corp')"),
});

export async function getClientContext(args: z.infer<typeof schema>) {
  const raw = args.client_name.toLowerCase().replace(/\s+/g, "-").replace(/[^a-z0-9-]/g, "");
  const name = args.client_name;

  // Find client by slug or fuzzy name match
  const { data: clients } = await db
    .from("clients")
    .select("*")
    .or(`slug.eq.${raw},name.ilike.%${name}%`)
    .limit(1);

  if (!clients || clients.length === 0) {
    return { error: `No client found matching "${args.client_name}". Try fsp_recall to search broadly.` };
  }

  const client = clients[0];

  const [projectsRes, memoriesRes, activityRes, decisionsRes] = await Promise.all([
    db.from("projects").select("*").eq("client_id", client.id).order("created_at", { ascending: false }).limit(10),
    db.from("memories").select("id,type,content,created_by,source,created_at").eq("client_id", client.id).order("created_at", { ascending: false }).limit(10),
    db.from("activity_log").select("staff_name,session_summary,created_at").eq("client_id", client.id).order("created_at", { ascending: false }).limit(5),
    db.from("decisions").select("title,content,category,decided_by,created_at").eq("status", "active").order("created_at", { ascending: false }).limit(5),
  ]);

  return {
    client: {
      name: client.name,
      industry: client.industry,
      status: client.status,
      notes: client.notes,
      since: client.created_at,
    },
    active_projects: projectsRes.data ?? [],
    recent_memories: memoriesRes.data ?? [],
    recent_activity: activityRes.data ?? [],
    relevant_decisions: decisionsRes.data ?? [],
  };
}
