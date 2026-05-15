import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { createServer, IncomingMessage, ServerResponse } from "node:http";

import { schema as getClientSchema, getClientContext } from "./tools/get-client.js";
import { schema as recallSchema, recall } from "./tools/recall.js";
import { schema as rememberSchema, remember } from "./tools/remember.js";
import { schema as logActivitySchema, logActivity } from "./tools/log-activity.js";
import { schema as listProjectsSchema, listActiveProjects } from "./tools/list-projects.js";
import { schema as searchDecisionsSchema, searchDecisions } from "./tools/search-decisions.js";
import { schema as teamActivitySchema, getTeamActivity } from "./tools/team-activity.js";
import { schema as buildAgentPromptSchema, buildAgentPrompt } from "./tools/build-agent-prompt.js";

const BEARER_TOKEN = process.env.FSP_BRAIN_TOKEN;
const PORT = parseInt(process.env.PORT ?? "3000", 10);

if (!BEARER_TOKEN) {
  throw new Error("FSP_BRAIN_TOKEN must be set");
}

function authError(res: ServerResponse) {
  res.writeHead(401, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ error: "Unauthorized" }));
}

function createMcpServer() {
  const server = new McpServer({
    name: "fsp-brain",
    version: "1.0.0",
  });

  server.tool(
    "fsp_get_client_context",
    "Get full context on a client — call this before starting any client work. Returns active projects, recent communications, decisions, and activity.",
    getClientSchema.shape,
    async (args) => {
      const result = await getClientContext(args as any);
      return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
    }
  );

  server.tool(
    "fsp_recall",
    "Semantic search across all shared memories — research, decisions, outputs, communications. Use natural language.",
    recallSchema.shape,
    async (args) => {
      const result = await recall(args as any);
      return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
    }
  );

  server.tool(
    "fsp_remember",
    "Store a memory, decision, research finding, or client note in the shared brain. All staff can recall it later.",
    rememberSchema.shape,
    async (args) => {
      const result = await remember(args as any);
      return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
    }
  );

  server.tool(
    "fsp_log_activity",
    "Log what was accomplished in this session. Called automatically by the session-end hook, or manually any time.",
    logActivitySchema.shape,
    async (args) => {
      const result = await logActivity(args as any);
      return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
    }
  );

  server.tool(
    "fsp_list_active_projects",
    "See all in-progress projects across the team, with owners and clients.",
    listProjectsSchema.shape,
    async (args) => {
      const result = await listActiveProjects(args as any);
      return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
    }
  );

  server.tool(
    "fsp_search_decisions",
    "Search company decisions and SOPs by topic. Use this before making any pricing, process, or vendor decision.",
    searchDecisionsSchema.shape,
    async (args) => {
      const result = await searchDecisions(args as any);
      return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
    }
  );

  server.tool(
    "fsp_get_team_activity",
    "See what the team has been working on recently, grouped by staff member.",
    teamActivitySchema.shape,
    async (args) => {
      const result = await getTeamActivity(args as any);
      return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
    }
  );

  server.tool(
    "fsp_build_agent_prompt",
    "Generate a CrewAI-style role-playing system prompt for an FSP agent. Pass role/goal/backstory and options to get back a ready-to-use system prompt (and optional separate user turn). Supports task_execution, lite_agent, planning, knowledge_search, and error templates.",
    buildAgentPromptSchema.shape,
    async (args) => {
      const result = await buildAgentPrompt(args as any);
      return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
    }
  );

  return server;
}

// One transport per session (stateless HTTP)
const httpServer = createServer(async (req: IncomingMessage, res: ServerResponse) => {
  // Health check (no auth required)
  if (req.method === "GET" && req.url === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ status: "ok", service: "fsp-brain", version: "1.0.0" }));
    return;
  }

  // Auth
  const auth = req.headers["authorization"] ?? "";
  if (!auth.startsWith("Bearer ") || auth.slice(7) !== BEARER_TOKEN) {
    authError(res);
    return;
  }

  // MCP endpoint
  if (req.url === "/mcp") {
    const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined });
    const server = createMcpServer();
    await server.connect(transport);
    await transport.handleRequest(req, res, await readBody(req));
    return;
  }

  // Simple REST endpoint for the session-end shell hook (can't call MCP from bash)
  if (req.method === "POST" && req.url === "/log") {
    try {
      const body = JSON.parse((await readBody(req)).toString());
      const result = await logActivity({
        summary: String(body.summary ?? "").slice(0, 1000),
        staff_name: String(body.staff_name ?? process.env.FSP_STAFF_NAME ?? "unknown"),
        client_name: body.client_name ? String(body.client_name) : undefined,
        project_name: body.project_name ? String(body.project_name) : undefined,
      });
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify(result));
    } catch (e) {
      res.writeHead(400, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: String(e) }));
    }
    return;
  }

  res.writeHead(404);
  res.end();
});

function readBody(req: IncomingMessage): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => resolve(Buffer.concat(chunks)));
    req.on("error", reject);
  });
}

httpServer.listen(PORT, () => {
  console.log(`FSP Brain MCP server listening on port ${PORT}`);
});
