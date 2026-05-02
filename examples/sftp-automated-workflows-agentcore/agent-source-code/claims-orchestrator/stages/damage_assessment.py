"""Damage assessment stage — invokes the DamageAssessmentAgent on AgentCore Runtime.

The agent analyzes claim photos for damage, researches repair costs, and returns
a structured JSON result. This stage parses the response and writes the damage
assessment to DynamoDB.
"""

import json
import logging
import os
import re
import uuid
from datetime import datetime, timezone
from decimal import Decimal

import boto3

logger = logging.getLogger(__name__)

DAMAGE_ASSESSMENT_AGENT_ARN = os.environ.get("DAMAGE_ASSESSMENT_AGENT_ARN", "")

agentcore_client = boto3.client("bedrock-agentcore")


def _convert_decimals(obj):
    """Convert floats to Decimal for DynamoDB compatibility."""
    if isinstance(obj, float):
        return Decimal(str(obj))
    if isinstance(obj, dict):
        return {k: _convert_decimals(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_convert_decimals(i) for i in obj]
    return obj


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _parse_assessment_result(agent_response: str) -> dict:
    """Parse the agent's JSON response into a damage assessment dict.

    The agent returns a JSON object either raw or wrapped in a markdown code block.
    """
    text = agent_response.strip()

    # Strip markdown code fences if present
    match = re.search(r"```(?:json)?\s*(\{.*\})\s*```", text, re.DOTALL)
    if match:
        text = match.group(1)
    else:
        # Try to find a raw JSON object
        start = text.find("{")
        end = text.rfind("}")
        if start != -1 and end != -1:
            text = text[start : end + 1]

    return json.loads(text)


def should_run(claim: dict) -> bool:
    """Only runs if the claim has photo documents.

    Checks the documents array for entries with doc_type == "photo"
    (from extraction results) or content_type starting with "image/".
    """
    documents = claim.get("documents", [])
    return any(
        doc.get("doc_type") == "photo" or doc.get("content_type", "").startswith("image/")
        for doc in documents
    )


def invoke(claim_id: str, claim: dict) -> dict:
    """Invoke the damage assessment agent via AgentCore Runtime."""
    session_id = f"orchestrator-dmg-{claim_id}-{uuid.uuid4()}"
    payload = json.dumps({"claim_id": claim_id, "session_id": session_id})

    logger.info("Invoking damage assessment agent for claim %s", claim_id)

    response = agentcore_client.invoke_agent_runtime(
        agentRuntimeArn=DAMAGE_ASSESSMENT_AGENT_ARN,
        runtimeSessionId=session_id,
        payload=payload.encode("utf-8"),
        contentType="application/json",
        accept="application/json",
    )

    # Collect streaming response as raw bytes, then decode once
    # (chunks can split multi-byte UTF-8 characters at boundaries)
    raw_chunks = []
    event_stream = response.get("response")
    if event_stream:
        for chunk in event_stream:
            if isinstance(chunk, bytes):
                raw_chunks.append(chunk)
            elif isinstance(chunk, dict):
                data = chunk.get("chunk", {}).get("bytes", b"")
                if data:
                    raw_chunks.append(data if isinstance(data, bytes) else data.encode("utf-8"))

    full_response = b"".join(raw_chunks).decode("utf-8", errors="replace")
    logger.info("Damage assessment agent response length: %d chars", len(full_response))

    return {"agent_response": full_response}


def update(claim_id: str, result: dict, table, **kwargs) -> None:
    """Parse agent response and write damage assessment to DynamoDB."""
    if result.get("skipped"):
        table.update_item(
            Key={"claim_id": claim_id},
            UpdateExpression="SET #s = :status, updated_at = :ts",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={":status": "damage_assessed", ":ts": _now()},
        )
        logger.info("Claim %s damage assessment skipped, status updated to damage_assessed", claim_id)
        return

    agent_response = result.get("agent_response", "")
    try:
        assessment = _parse_assessment_result(agent_response)
        assessment = _convert_decimals(assessment)
    except (json.JSONDecodeError, ValueError) as e:
        logger.error("Failed to parse damage assessment response for claim %s: %s", claim_id, e)
        assessment = {"raw_response": agent_response, "parse_error": str(e)}

    table.update_item(
        Key={"claim_id": claim_id},
        UpdateExpression="SET #s = :status, damage_assessment = :da, updated_at = :ts",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={
            ":status": "damage_assessed",
            ":da": assessment,
            ":ts": _now(),
        },
    )
    logger.info("Claim %s status updated to damage_assessed", claim_id)
