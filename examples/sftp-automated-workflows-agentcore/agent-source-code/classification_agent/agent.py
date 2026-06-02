"""Classification agent setup — threshold-based routing with MCP gateway.

Reads the full claim record (submission, extractions, damage assessment, fraud
assessment) and routes to approved/requires_review/rejected based on condition
checks. Does NOT re-weight — the fraud agent already scored the claim.
Rules loaded from static config or dynamically from gateway.
"""

import logging
import os
from contextlib import ExitStack, contextmanager
from pathlib import Path

import boto3
from strands import Agent
from strands.models import BedrockModel

from agentcore_mcp_client import AgentCoreMCPClient
from config import CLASSIFICATION_RULES
from tools import GATEWAY_ARN, GATEWAY_URL, TOOLS

logger = logging.getLogger(__name__)

GUARDRAIL_ID = os.environ.get("GUARDRAIL_ID", "")
GUARDRAIL_VERSION = os.environ.get("GUARDRAIL_VERSION", "")

PROMPTS_DIR = Path(__file__).parent / "prompts"


def _build_rules_section(rules: dict) -> str:
    """Build the rules section for the system prompt from the active rules dict."""
    lines = []
    # Priority order: rejected first, then requires_review, then approved
    for outcome in ["rejected", "requires_review", "approved"]:
        group = rules.get(outcome)
        if not group:
            continue
        lines.append(f"### {outcome.upper()}")
        lines.append(f"{group['description']}")
        lines.append("")
        for i, cond in enumerate(group.get("conditions", []), 1):
            line = f"{i}. **{cond['id']}**: {cond['description']}"
            if cond.get("params"):
                line += f" Parameters: {cond['params']}"
            lines.append(line)
        lines.append("")
    return "\n".join(lines)


def _build_system_prompt(rules: dict) -> str:
    """Load the system prompt template and fill in dynamic rule descriptions."""
    template = (PROMPTS_DIR / "system_prompt.txt").read_text()
    return template.format(rules_section=_build_rules_section(rules))


@contextmanager
def get_agent(session_id: str):
    """Create a classification agent with built-in tools and optional MCP tools."""
    region = os.environ.get("AWS_REGION", os.environ.get("AWS_DEFAULT_REGION", "us-east-1"))

    model_kwargs = {"region_name": region}
    if GUARDRAIL_ID and GUARDRAIL_VERSION:
        model_kwargs.update(
            guardrail_id=GUARDRAIL_ID,
            guardrail_version=GUARDRAIL_VERSION,
            guardrail_trace="enabled",
            guardrail_redact_input=True,
            guardrail_redact_output=False,
        )

    model = BedrockModel(**model_kwargs)
    tools = list(TOOLS)
    active_rules = dict(CLASSIFICATION_RULES)

    logger.info("Built-in tools loaded: %s", [getattr(t, "__name__", getattr(t, "name", str(t))) for t in tools])

    mcp_target = GATEWAY_URL or GATEWAY_ARN
    if mcp_target:
        try:
            session = boto3.Session(region_name=region)
            credentials = session.get_credentials().get_frozen_credentials()

            if GATEWAY_URL:
                mcp_client = AgentCoreMCPClient.with_gateway_url(
                    gateway_url=GATEWAY_URL,
                    credentials=credentials,
                    region=region,
                    session_id=session_id,
                )
            else:
                mcp_client = AgentCoreMCPClient.with_iam_auth(
                    agent_runtime_arn=GATEWAY_ARN,
                    credentials=credentials,
                    region=region,
                    session_id=session_id,
                )

            with ExitStack() as stack:
                stack.enter_context(mcp_client)
                mcp_tools = mcp_client.list_tools_sync()
                logger.info("MCP tools loaded: %s", [getattr(t, "name", str(t)) for t in mcp_tools])
                tools.extend(mcp_tools)

                # Dynamic rules: if insurer provides get_classification_rules via gateway,
                # override static config with their custom rules.
                rules_tool = next(
                    (t for t in mcp_tools if getattr(t, "name", "") == "get_classification_rules"),
                    None,
                )
                if rules_tool:
                    try:
                        custom_rules = rules_tool()
                        if isinstance(custom_rules, dict) and custom_rules:
                            active_rules = custom_rules
                            logger.info("Loaded custom classification rules from gateway")
                    except Exception as e:
                        logger.warning("Failed to load custom classification rules: %s — using static config", e)

                logger.info(
                    "Agent created with %d total tools: %s",
                    len(tools),
                    [getattr(t, "__name__", getattr(t, "name", str(t))) for t in tools],
                )
                yield Agent(
                    system_prompt=_build_system_prompt(active_rules),
                    tools=tools,
                    model=model,
                )
                return
        except Exception as e:
            logger.warning(
                "MCP gateway connection failed (%s), continuing with built-in tools only: %s",
                "URL" if GATEWAY_URL else "ARN",
                e,
            )

    # Fallback — no gateway or gateway failed
    logger.info(
        "Fallback: Agent created with %d built-in tools only: %s",
        len(tools),
        [getattr(t, "__name__", getattr(t, "name", str(t))) for t in tools],
    )
    yield Agent(
        system_prompt=_build_system_prompt(active_rules),
        tools=tools,
        model=model,
    )
