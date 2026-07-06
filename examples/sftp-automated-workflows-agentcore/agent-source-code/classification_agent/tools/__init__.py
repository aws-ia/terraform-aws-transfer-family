"""Tool registry for the classification agent.

No built-in tools — classification reads the claim record only.
External MCP tools (Claim Reader) loaded via shared claims-gateway.
"""

import os

TOOLS = []

GATEWAY_URL = os.environ.get("AGENTCORE_GATEWAY_URL", "")
GATEWAY_ARN = os.environ.get("AGENTCORE_GATEWAY_ARN", "")
