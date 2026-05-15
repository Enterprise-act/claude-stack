/**
 * Prompt assembly system modelled after CrewAI's prompts.py + en.json.
 * Assembles role-playing system/user prompts from composable slices.
 */

import { createRequire } from "module";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const translations: Record<string, any> = require(join(__dirname, "en.json"));

type SliceKey =
  | "role_playing"
  | "tools"
  | "no_tools"
  | "native_tools"
  | "task"
  | "native_task"
  | "task_no_tools";

export interface AgentConfig {
  role: string;
  goal: string;
  backstory: string;
  hasTools?: boolean;
  useNativeToolCalling?: boolean;
  useSystemPrompt?: boolean;
  /** Optional extra skill context appended to the system prompt. */
  skillContext?: string;
}

export interface PromptResult {
  /** Full concatenated prompt (system + user combined, for single-message APIs). */
  prompt: string;
  /** Separate system turn (populated when useSystemPrompt is true). */
  system?: string;
  /** Separate user turn (populated when useSystemPrompt is true). */
  user?: string;
}

function slice(key: SliceKey): string {
  return translations.slices?.[key] ?? "";
}

function fillAgentVars(text: string, agent: AgentConfig): string {
  return text
    .replace(/\{role\}/g, agent.role)
    .replace(/\{goal\}/g, agent.goal)
    .replace(/\{backstory\}/g, agent.backstory);
}

function buildSlices(keys: SliceKey[], agent: AgentConfig): string {
  return fillAgentVars(keys.map(slice).join(""), agent);
}

/**
 * Returns the manager agent definition from en.json.
 */
export function managerAgentConfig(): Pick<AgentConfig, "role" | "goal" | "backstory"> {
  return translations.hierarchical_manager_agent;
}

/**
 * Retrieves a raw error template by key.
 */
export function errorTemplate(key: keyof typeof translations.errors): string {
  return translations.errors?.[key] ?? "";
}

/**
 * Retrieves a raw tool description template by key.
 */
export function toolTemplate(key: keyof typeof translations.tools): string {
  return translations.tools?.[key] ?? "";
}

/**
 * Retrieves any planning prompt by key.
 */
export function planningPrompt(key: keyof typeof translations.planning): string {
  return translations.planning?.[key] ?? "";
}

/**
 * Assembles a task-execution prompt for an agent.
 *
 * Mirrors CrewAI's `Prompts.task_execution()` logic:
 *   system = role_playing + tools|no_tools
 *   user   = task|task_no_tools|native_task
 *
 * When `useSystemPrompt` is true the result includes separate `system` and
 * `user` fields suitable for APIs that support a system role (e.g. Anthropic).
 * Otherwise only `prompt` (combined) is set.
 */
export function buildTaskExecutionPrompt(agent: AgentConfig): PromptResult {
  const systemSlices: SliceKey[] = ["role_playing"];

  if (agent.hasTools) {
    if (!agent.useNativeToolCalling) {
      systemSlices.push("tools");
    }
    // native tool calling: no extra text slice needed
  } else {
    systemSlices.push("no_tools");
  }

  const systemText =
    buildSlices(systemSlices, agent) + (agent.skillContext ? `\n\n${agent.skillContext}` : "");

  let taskSlice: SliceKey;
  if (agent.useNativeToolCalling) {
    taskSlice = "native_task";
  } else if (agent.hasTools) {
    taskSlice = "task";
  } else {
    taskSlice = "task_no_tools";
  }

  const userText = buildSlices([taskSlice], agent);

  if (agent.useSystemPrompt) {
    return {
      system: systemText,
      user: userText,
      prompt: systemText + userText,
    };
  }

  return {
    prompt: systemText + userText,
  };
}

/**
 * Builds a "lite" self-contained system prompt (role + backstory + goal + tools
 * in a single message). Useful for simpler agent wrappers.
 */
export function buildLiteAgentPrompt(
  agent: AgentConfig,
  toolList?: string,
  toolNames?: string
): string {
  const templateKey = agent.hasTools
    ? "lite_agent_system_prompt_with_tools"
    : "lite_agent_system_prompt_without_tools";

  let text: string = translations.slices?.[templateKey] ?? "";
  text = fillAgentVars(text, agent);
  if (toolList) text = text.replace(/\{tools\}/g, toolList);
  if (toolNames) text = text.replace(/\{tool_names\}/g, toolNames);
  return text;
}

/**
 * Injects memory context into the memory slice template.
 */
export function buildMemorySlice(memories: string): string {
  return (translations.slices?.memory ?? "").replace(/\{memory\}/g, memories);
}

/**
 * Appends expected-output criteria to a task prompt.
 */
export function buildExpectedOutputSlice(expectedOutput: string): string {
  return (translations.slices?.expected_output ?? "").replace(
    /\{expected_output\}/g,
    expectedOutput
  );
}

/**
 * Builds the knowledge-search rewrite system prompt (verbatim from en.json).
 */
export function knowledgeSearchSystemPrompt(): string {
  return translations.slices?.knowledge_search_query_system_prompt ?? "";
}

/**
 * Wraps a task prompt with context from previous steps.
 */
export function buildTaskWithContext(task: string, context: string): string {
  return (translations.slices?.task_with_context ?? "")
    .replace(/\{task\}/g, task)
    .replace(/\{context\}/g, context);
}
