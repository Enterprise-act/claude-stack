import { z } from "zod";
import { db } from "../db.js";
import { embed } from "../embeddings.js";

export const schema = z.object({
  query: z.string().describe("What to search for — natural language, any topic"),
  type: z.enum(["decision", "research", "output", "communication", "sop", "client_note", "task_state"]).optional().describe("Filter by memory type"),
  client_name: z.string().optional().describe("Limit search to a specific client"),
  limit: z.number().int().min(1).max(20).default(8).describe("Max results to return"),
});

export async function recall(args: z.infer<typeof schema>) {
  const vector = await embed(args.query);

  let clientId: string | undefined;
  if (args.client_name) {
    const slug = args.client_name.toLowerCase().replace(/\s+/g, "-").replace(/[^a-z0-9-]/g, "");
    const { data } = await db
      .from("clients")
      .select("id")
      .or(`slug.eq.${slug},name.ilike.%${args.client_name}%`)
      .limit(1);
    clientId = data?.[0]?.id;
  }

  // Supabase vector similarity search via RPC
  const { data, error } = await db.rpc("match_memories", {
    query_embedding: vector,
    match_threshold: 0.3,
    match_count: args.limit,
    filter_type: args.type ?? null,
    filter_client_id: clientId ?? null,
  });

  if (error) {
    // Fallback: text search if pgvector RPC not yet set up
    let q = db.from("memories").select("id,type,content,created_by,client_id,source,created_at").order("created_at", { ascending: false }).limit(args.limit);
    if (args.type) q = q.eq("type", args.type);
    if (clientId) q = q.eq("client_id", clientId);
    const { data: fallback } = await q.ilike("content", `%${args.query}%`);
    return { results: fallback ?? [], search_mode: "text_fallback" };
  }

  return { results: data ?? [], search_mode: "semantic" };
}
