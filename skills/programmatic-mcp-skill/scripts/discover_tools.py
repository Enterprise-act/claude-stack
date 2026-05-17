#!/usr/bin/env python3
"""Discover all tools exposed by an MCP server.

Usage:
    python discover_tools.py <command> [args...]

Examples:
    python discover_tools.py npx -y @modelcontextprotocol/server-filesystem /tmp
    python discover_tools.py npx -y @playwright/mcp@latest
    python discover_tools.py node ./my-server.js
"""

import asyncio
import json
import sys

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

_CONNECT_TIMEOUT = 10  # seconds to wait for the MCP server to start and initialize


async def discover(command: str, args: list[str]):
    server_params = StdioServerParameters(command=command, args=args, env=None)

    try:
        async with stdio_client(server_params) as (read, write):
            async with ClientSession(read, write) as session:
                try:
                    await asyncio.wait_for(session.initialize(), timeout=_CONNECT_TIMEOUT)
                except asyncio.TimeoutError:
                    print(
                        json.dumps({"error": "server_unavailable", "reason": "initialize timed out",
                                    "server": command}),
                        file=sys.stderr,
                    )
                    sys.exit(1)

                tools = await session.list_tools()
                print(f"Found {len(tools.tools)} tools:\n")

                for tool in tools.tools:
                    print(f"  {tool.name}")
                    if tool.description:
                        print(f"    {tool.description[:100]}")
                    if tool.inputSchema:
                        props = tool.inputSchema.get("properties", {})
                        required = tool.inputSchema.get("required", [])
                        for name, info in props.items():
                            req = " *" if name in required else ""
                            desc = info.get("description", "")
                            print(f"    - {name}: {info.get('type', 'any')}{req}  {desc[:60]}")
                    print()

    except Exception as exc:
        print(
            json.dumps({"error": "server_unavailable", "reason": str(exc), "server": command}),
            file=sys.stderr,
        )
        sys.exit(1)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    command = sys.argv[1]
    args = sys.argv[2:]
    asyncio.run(discover(command, args))


if __name__ == "__main__":
    main()
