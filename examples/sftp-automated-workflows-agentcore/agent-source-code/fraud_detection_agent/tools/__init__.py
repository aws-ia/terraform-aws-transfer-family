"""Tool registry for the fraud detection agent.

Built-in tools handle checks that require capabilities beyond text analysis
(e.g. image inspection via Bedrock vision). All data-comparison fraud checks
are LLM-driven via the system prompt and configurable rules in config/rules.py.
External MCP tools (Claim Reader, optional custom tools) loaded via shared
claims-gateway at runtime.
"""

import os

from .photo_integrity import analyze_photo_integrity

# Built-in tools — only photo integrity needs a separate model call
TOOLS = [analyze_photo_integrity]

# AgentCore Gateway config for external MCP tools
GATEWAY_URL = os.environ.get("AGENTCORE_GATEWAY_URL", "")
GATEWAY_ARN = os.environ.get("AGENTCORE_GATEWAY_ARN", "")
