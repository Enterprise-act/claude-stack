import { z } from "zod";
import { db } from "../db.js";
import { embed } from "../embeddings.js";

export const schema = z.object({
  content: z.string().min(1).describe("The information to store — be specific and complete"),
  type: z.enum(["decision", "research", "output", "communication", "sop", "client_note", "task_state"]).describe("Category of this memory"),
  client_name: z.string().optional().describe("Associate with this client"),
  project_name: z.string().optional().describe("Associate with this project"),
  tags: z.array(z.string()).default([]).describe("Optional tags for filtering"),
  source: z.string().default("claude_session").describe("Where this came from"),
  created_by: z.string().optional().describe("Staff name (defaults to FSP_STAFF_NAME env var)"),
});

export async function remember(args: z.infer<typeof schema>) {
  const staffName = args.created_by ?? process.env.FSP_STAFF_NAME ?? "unknown";

  // Resolve client
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

  // Resolve project
  let projectId: string | undefined;
  if (args.project_name && clientId) {
    const { data } = await db
      .from("projects")
      .select("id")
      .eq("client_id", clientId)
      .ilike("name", `%${args.project_name}%`)
      .limit(1);
    projectId = data?.[0]?.id;
  }

  // Generate embedding
  const embedding = await embed(args.content);

  const { data, error } = await db.from("memories").insert({
    type: args.type,
    content: args.content,
    embedding,
    client_id: clientId ?? null,
    project_id: projectId ?? null,
    created_by: staffName,
    source: args.source,
    tags: args.tags,
  }).select("id,type,created_at").single();

  if (error) return { error: error.message };

  return {
    stored: true,
    id: data.id,
    type: args.type,
    client_id: clientId ?? null,
    project_id: projectId ?? null,
    created_at: data.created_at,
  };
}
