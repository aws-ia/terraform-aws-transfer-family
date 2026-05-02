"""Fraud detection stage — invokes the FraudDetectionAgent on AgentCore Runtime.

The agent analyzes claim data for anomalies (policy validity, coverage mismatches,
estimate deviations, photo manipulation) and returns a structured fraud risk profile.
This stage parses the response and writes the fraud assessment to DynamoDB.
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

FRAUD_DETECTION_AGENT_ARN = os.environ.get("FRAUD_DETECTION_AGENT_ARN", "")

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
    """Parse the agent's JSON response into a fraud assessment dict."""
    text = agent_response.strip()

    match = re.search(r"```(?:json)?\s*(\{.*\})\s*```", text, re.DOTALL)
    if match:
        text = match.group(1)
    else:
        start = text.find("{")
        end = text.rfind("}")
        if start != -1 and end != -1:
            text = text[start : end + 1]

    return json.loads(text)


def should_run(claim: dict) -> bool:
    """Always runs — fraud checks apply to every claim."""
    return True


def invoke(claim_id: str, claim: dict) -> dict:
    """Invoke the fraud detection agent via AgentCore Runtime."""
    session_id = f"orchestrator-fraud-{claim_id}-{uuid.uuid4()}"
    payload = json.dumps({"claim_id": claim_id, "session_id": session_id})

    logger.info("Invoking fraud detection agent for claim %s", claim_id)

    response = agentcore_client.invoke_agent_runtime(
        agentRuntimeArn=FRAUD_DETECTION_AGENT_ARN,
        runtimeSessionId=session_id,
        payload=payload.encode("utf-8"),
        contentType="application/json",
        accept="application/json",
    )

    # Collect streaming response as raw bytes, then decode once
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
    logger.info("Fraud detection agent response length: %d chars", len(full_response))

    return {"agent_response": full_response}


def update(claim_id: str, result: dict, table, **kwargs) -> None:
    """Parse agent response and write fraud assessment to DynamoDB."""
    agent_response = result.get("agent_response", "")
    try:
        assessment = _parse_assessment_result(agent_response)
        assessment = _convert_decimals(assessment)
    except (json.JSONDecodeError, ValueError) as e:
        logger.error(
            "Failed to parse fraud detection response for claim %s: %s", claim_id, e
        )
        assessment = {"raw_response": agent_response, "parse_error": str(e)}

    table.update_item(
        Key={"claim_id": claim_id},
        UpdateExpression="SET #s = :status, fraud_assessment = :fa, updated_at = :ts",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={
            ":status": "fraud_checked",
            ":fa": assessment,
            ":ts": _now(),
        },
    )
    logger.info("Claim %s status updated to fraud_checked", claim_id)
