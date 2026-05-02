"""Tool registry for the damage assessment agent.

Built-in tools are always available. External MCP tools (Fetch, Claim Reader)
are loaded dynamically via the shared AgentCore Gateway when GATEWAY_URL or
GATEWAY_ARN is set.

get_claim_data and get_claim_photos are now served by the claim-reader MCP
server behind the gateway — enabling plug-and-play backend swaps per insurer.
"""

import os

from .photo_analyzer import analyze_photo

# Built-in tools — always available
TOOLS = [analyze_photo]

# AgentCore Gateway config for external MCP tools (Fetch + Claim Reader).
# agent.py prefers GATEWAY_URL (direct HTTPS) over GATEWAY_ARN (ARN-based invocation).
GATEWAY_URL = os.environ.get("AGENTCORE_GATEWAY_URL", "")
GATEWAY_ARN = os.environ.get("AGENTCORE_GATEWAY_ARN", "")
