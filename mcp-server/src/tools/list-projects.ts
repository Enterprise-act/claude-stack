import { z } from "zod";
import { db } from "../db.js";

export const schema = z.object({
  status: z.enum(["active", "completed", "paused", "all"]).default("active").describe("Filter by project status"),
});

export async function listActiveProjects(args: z.infer<typeof schema>) {
  let q = db
    .from("projects")
    .select(`
      id, name, status, owner_name, due_date, created_at,
      clients (name, slug, industry)
    `)
    .order("created_at", { ascending: false });

  if (args.status !== "all") {
    q = q.eq("status", args.status);
  }

  const { data, error } = await q;
  if (error) return { error: error.message };

  return {
    count: data?.length ?? 0,
    projects: data ?? [],
  };
}
