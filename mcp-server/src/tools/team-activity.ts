import { z } from "zod";
import { db } from "../db.js";

export const schema = z.object({
  days: z.number().int().min(1).max(90).default(7).describe("How many days back to look"),
  staff_name: z.string().optional().describe("Filter to a specific staff member"),
});

export async function getTeamActivity(args: z.infer<typeof schema>) {
  const since = new Date(Date.now() - args.days * 24 * 60 * 60 * 1000).toISOString();

  let q = db
    .from("activity_log")
    .select(`
      staff_name, session_summary, duration_mins, created_at,
      clients (name, slug),
      projects (name)
    `)
    .gte("created_at", since)
    .order("created_at", { ascending: false });

  if (args.staff_name) {
    q = q.ilike("staff_name", `%${args.staff_name}%`);
  }

  const { data, error } = await q;
  if (error) return { error: error.message };

  const entries = data ?? [];

  // Group by staff member for a quick overview
  const byStaff: Record<string, typeof entries> = {};
  for (const entry of entries) {
    const name = entry.staff_name;
    if (!byStaff[name]) byStaff[name] = [];
    byStaff[name].push(entry);
  }

  return {
    period_days: args.days,
    total_sessions: entries.length,
    by_staff: byStaff,
  };
}
