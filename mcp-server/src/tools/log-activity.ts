import { z } from "zod";
import { db } from "../db.js";

export const schema = z.object({
  summary: z.string().min(1).describe("2–3 sentence summary of what was accomplished this session"),
  client_name: z.string().optional().describe("Client this session was for"),
  project_name: z.string().optional().describe("Specific project worked on"),
  duration_mins: z.number().int().min(0).optional().describe("Approximate session duration in minutes"),
  staff_name: z.string().optional().describe("Who did the work (defaults to FSP_STAFF_NAME env var)"),
});

export async function logActivity(args: z.infer<typeof schema>) {
  const staffName = args.staff_name ?? process.env.FSP_STAFF_NAME ?? "unknown";

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

  const { data, error } = await db.from("activity_log").insert({
    staff_name: staffName,
    session_summary: args.summary,
    client_id: clientId ?? null,
    project_id: projectId ?? null,
    duration_mins: args.duration_mins ?? null,
  }).select("id,created_at").single();

  if (error) return { error: error.message };

  return { logged: true, id: data.id, staff_name: staffName, created_at: data.created_at };
}
