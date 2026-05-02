"""Damage assessment agent setup — loads built-in tools and MCP tools from gateway."""

import os
from contextlib import ExitStack, contextmanager
from pathlib import Path

import boto3
from strands import Agent
from strands.models import BedrockModel

from agentcore_mcp_client import AgentCoreMCPClient
from config import DAMAGE_TYPE_DESCRIPTIONS, DamageType, Severity
from tools import GATEWAY_ARN, GATEWAY_URL, TOOLS

GUARDRAIL_ID = os.environ.get("GUARDRAIL_ID", "")
GUARDRAIL_VERSION = os.environ.get("GUARDRAIL_VERSION", "")

PROMPTS_DIR = Path(__file__).parent / "prompts"

import json

REPAIR_COSTS_PATH = Path(__file__).parent / "config" / "repair_costs.json"


def _load_repair_costs() -> str:
    """Load bundled repair cost reference data."""
    return REPAIR_COSTS_PATH.read_text()


def _build_system_prompt() -> str:
    """Load the system prompt template and fill in dynamic config values."""
    template = (PROMPTS_DIR / "system_prompt.txt").read_text()
    return template.format(
        damage_types=", ".join(dt.value for dt in DamageType),
        severity_levels=", ".join(s.value for s in Severity),
        damage_type_descriptions="\n".join(f"- {dt.value}: {desc}" for dt, desc in DAMAGE_TYPE_DESCRIPTIONS.items()),
        repair_cost_reference=_load_repair_costs(),
    )


@contextmanager
def get_agent(session_id: str):
    """Create a damage assessment agent with built-in tools and optional MCP tools."""
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

    agent_kwargs = dict(
        system_prompt=_build_system_prompt(),
        tools=tools,
        model=model,
    )

    # Try to connect to the MCP gateway for external tools (e.g. Fetch).
    # Prefer the direct gateway URL over the ARN-based runtime URL.
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
                tools.extend(mcp_client.list_tools_sync())
                yield Agent(**agent_kwargs)
                return
        except Exception as e:
            import logging

            logging.getLogger(__name__).warning(
                "MCP gateway connection failed (%s), continuing with built-in tools only: %s",
                "URL" if GATEWAY_URL else "ARN",
                e,
            )

    # Fallback — no gateway or gateway failed
    yield Agent(**agent_kwargs)
