import { z } from "zod";
import { db } from "../db.js";

export const schema = z.object({
  topic: z.string().describe("What decision or SOP to search for"),
  category: z.enum(["pricing", "process", "client", "vendor", "product", "hr"]).optional().describe("Filter by category"),
});

export async function searchDecisions(args: z.infer<typeof schema>) {
  let q = db
    .from("decisions")
    .select("*")
    .eq("status", "active")
    .ilike("content", `%${args.topic}%`)
    .order("created_at", { ascending: false })
    .limit(10);

  if (args.category) {
    q = q.eq("category", args.category);
  }

  const { data, error } = await q;
  if (error) return { error: error.message };

  // Also search title
  const { data: titleMatches } = await db
    .from("decisions")
    .select("*")
    .eq("status", "active")
    .ilike("title", `%${args.topic}%`)
    .order("created_at", { ascending: false })
    .limit(5);

  const combined = [...(data ?? []), ...(titleMatches ?? [])];
  const unique = Array.from(new Map(combined.map((d) => [d.id, d])).values());

  return { count: unique.length, decisions: unique };
}
