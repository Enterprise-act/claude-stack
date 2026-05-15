import { z } from "zod";
import {
  buildTaskExecutionPrompt,
  buildLiteAgentPrompt,
  buildMemorySlice,
  buildExpectedOutputSlice,
  buildTaskWithContext,
  managerAgentConfig,
  errorTemplate,
  planningPrompt,
  knowledgeSearchSystemPrompt,
  type AgentConfig,
} from "../prompts/prompts.js";

export const schema = z.object({
  role: z.string().describe("The agent's role title, e.g. 'Senior Copywriter'"),
  goal: z.string().describe("The agent's personal goal for this task"),
  backstory: z.string().describe("The agent's backstory / expertise description"),
  has_tools: z
    .boolean()
    .optional()
    .default(false)
    .describe("Whether the agent has tools available"),
  use_native_tool_calling: z
    .boolean()
    .optional()
    .default(false)
    .describe("Use native function calling instead of ReAct text format"),
  use_system_prompt: z
    .boolean()
    .optional()
    .default(false)
    .describe("Return separate system + user fields (for Anthropic/OpenAI system role)"),
  lite_mode: z
    .boolean()
    .optional()
    .default(false)
    .describe("Return a single self-contained lite prompt instead of system+user split"),
  tool_list: z
    .string()
    .optional()
    .describe("Formatted list of available tools (for lite_mode or tools slice)"),
  tool_names: z.string().optional().describe("Comma-separated list of tool names"),
  memory: z.string().optional().describe("Past memories to inject into the prompt"),
  expected_output: z.string().optional().describe("Expected output criteria to append"),
  task_context: z
    .string()
    .optional()
    .describe("Context from previous steps to wrap around the task prompt"),
  task: z.string().optional().describe("The task text (used when task_context is provided)"),
  use_manager_defaults: z
    .boolean()
    .optional()
    .default(false)
    .describe("Use the default FSP manager agent role/goal/backstory"),
  prompt_type: z
    .enum([
      "task_execution",
      "lite_agent",
      "planning_system",
      "planning_create",
      "knowledge_search_system",
      "error",
    ])
    .optional()
    .default("task_execution")
    .describe("Which prompt template to generate"),
  error_key: z
    .enum([
      "force_final_answer",
      "force_final_answer_error",
      "task_repeated_usage",
      "tool_usage_error",
      "tool_arguments_error",
      "wrong_tool_name",
      "validation_error",
    ])
    .optional()
    .describe("Which error template to return (when prompt_type is 'error')"),
});

export type BuildAgentPromptArgs = z.infer<typeof schema>;

export async function buildAgentPrompt(args: BuildAgentPromptArgs): Promise<{
  prompt?: string;
  system?: string;
  user?: string;
  note?: string;
}> {
  let agentConfig: AgentConfig;

  if (args.use_manager_defaults) {
    const mgr = managerAgentConfig();
    agentConfig = {
      role: mgr.role,
      goal: mgr.goal,
      backstory: mgr.backstory,
      hasTools: args.has_tools,
      useNativeToolCalling: args.use_native_tool_calling,
      useSystemPrompt: args.use_system_prompt,
    };
  } else {
    agentConfig = {
      role: args.role,
      goal: args.goal,
      backstory: args.backstory,
      hasTools: args.has_tools,
      useNativeToolCalling: args.use_native_tool_calling,
      useSystemPrompt: args.use_system_prompt,
    };
  }

  switch (args.prompt_type) {
    case "task_execution": {
      const result = buildTaskExecutionPrompt(agentConfig);

      let prompt = result.prompt;
      let system = result.system;

      // Optionally inject memory and expected_output
      if (args.memory) {
        const memSlice = buildMemorySlice(args.memory);
        if (system) system += memSlice;
        else prompt += memSlice;
      }

      if (args.expected_output) {
        const outSlice = buildExpectedOutputSlice(args.expected_output);
        if (system) system += outSlice;
        else prompt += outSlice;
      }

      if (args.task && args.task_context) {
        const withCtx = buildTaskWithContext(args.task, args.task_context);
        if (result.user !== undefined) {
          return { system, user: withCtx, prompt: (system ?? "") + withCtx };
        }
        prompt += "\n\n" + withCtx;
      }

      return { prompt, system, user: result.user };
    }

    case "lite_agent": {
      const prompt = buildLiteAgentPrompt(agentConfig, args.tool_list, args.tool_names);
      return { prompt };
    }

    case "planning_system": {
      return { prompt: planningPrompt("system_prompt") };
    }

    case "planning_create": {
      return {
        prompt: planningPrompt("create_plan_prompt"),
        note: "Fill in {description}, {expected_output}, {tools}, {max_steps} before sending.",
      };
    }

    case "knowledge_search_system": {
      return { prompt: knowledgeSearchSystemPrompt() };
    }

    case "error": {
      if (!args.error_key) {
        return { prompt: "error_key is required when prompt_type is 'error'" };
      }
      return { prompt: errorTemplate(args.error_key as any) };
    }

    default:
      return { prompt: "" };
  }
}
