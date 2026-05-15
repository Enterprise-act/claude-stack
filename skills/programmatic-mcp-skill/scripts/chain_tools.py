#!/usr/bin/env python3
"""Chain multiple MCP tool calls together in a pipeline.

This script demonstrates chaining tools from a filesystem MCP server.
Modify the pipeline() function for your use case.

Usage:
    python chain_tools.py <command> [args...]

Example:
    python chain_tools.py npx -y @modelcontextprotocol/server-filesystem /tmp
"""

import asyncio
import json
import sys
from contextlib import asynccontextmanager

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

# Safety limits
_MAX_FILES = 50          # max .txt/.md files read per pipeline run
_CALL_TIMEOUT = 30       # seconds per individual tool call
_BUDGET_CHARS = 200_000  # total chars accumulated before warning (≈50k tokens)


@asynccontextmanager
async def mcp_client(command: str, args: list[str], env: dict | None = None):
    """Reusable MCP client context manager."""
    server_params = StdioServerParameters(command=command, args=args, env=env)
    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            yield session


async def _call(session: ClientSession, tool_name: str, arguments: dict) -> str:
    """Call a tool with a per-call timeout; return text content or empty string."""
    result = await asyncio.wait_for(
        session.call_tool(tool_name, arguments), timeout=_CALL_TIMEOUT
    )
    if not result.content:
        return ""
    return result.content[0].text if hasattr(result.content[0], "text") else ""


async def pipeline(command: str, args: list[str]):
    async with mcp_client(command, args) as session:
        # Step 1: List tools to see what's available
        tools = await session.list_tools()
        tool_names = [t.name for t in tools.tools]
        print(f"Available tools: {tool_names}\n")

        accumulated_chars = 0

        # Step 2: List the root directory
        if "list_directory" in tool_names:
            entries = await _call(session, "list_directory", {"path": args[-1]})
            print(f"Directory listing:\n{entries}\n")
            accumulated_chars += len(entries)

            # Step 3: Read any .txt or .md files found
            if "read_file" in tool_names:
                files_read = 0
                for line in entries.split("\n"):
                    if files_read >= _MAX_FILES:
                        print(f"[chain_tools] Reached max_files limit ({_MAX_FILES}). Stopping.")
                        break
                    name = line.strip().lstrip("[FILE] ").lstrip("[DIR] ")
                    if name.endswith((".txt", ".md")):
                        path = f"{args[-1]}/{name}"
                        try:
                            content = await _call(session, "read_file", {"path": path})
                            accumulated_chars += len(content)
                            if accumulated_chars > _BUDGET_CHARS:
                                print(
                                    f"[chain_tools] Character budget exceeded "
                                    f"({accumulated_chars:,} > {_BUDGET_CHARS:,}). Stopping."
                                )
                                break
                            print(f"--- {name} ({len(content)} chars) ---")
                            print(content[:500])
                            print()
                            files_read += 1
                        except asyncio.TimeoutError:
                            print(f"[chain_tools] Timeout reading {name} — skipping.")
                        except Exception as e:
                            print(f"Could not read {name}: {e}")

        print("Pipeline complete.")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    command = sys.argv[1]
    args = sys.argv[2:]
    asyncio.run(pipeline(command, args))


if __name__ == "__main__":
    main()
