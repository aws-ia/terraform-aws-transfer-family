"""Document extraction stage — invokes the DocumentExtractionAgent on AgentCore Runtime.

The agent reads documents from S3, extracts structured data, and returns a JSON array.
This stage parses the response and writes the extraction results to DynamoDB.
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

DOCUMENT_EXTRACTION_AGENT_ARN = os.environ.get("DOCUMENT_EXTRACTION_AGENT_ARN", "")
USER_POLICIES_TABLE = os.environ.get("USER_POLICIES_TABLE", "")

agentcore_client = boto3.client("bedrock-agentcore")
dynamodb = boto3.resource("dynamodb")


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


def _get_pre_extracted_policy(claim: dict) -> list:
    """Check user-policies table for a pre-extracted policy document.

    If the claimant has a policy_document uploaded by an adjuster for the
    policy_number on this claim, return it as a synthetic extraction entry
    so downstream agents can use it without re-extracting.
    """
    if not USER_POLICIES_TABLE:
        return []

    policy_number = claim.get("policy_number", "")
    claimant_username = claim.get("claimant_username", "")
    if not policy_number or not claimant_username:
        return []

    try:
        table = dynamodb.Table(USER_POLICIES_TABLE)
        resp = table.get_item(Key={"username": claimant_username})
        item = resp.get("Item")
        if not item:
            return []

        policy_docs = item.get("policy_documents", {})
        doc_entry = policy_docs.get(policy_number)
        if not doc_entry or not doc_entry.get("extracted"):
            return []

        extracted = doc_entry["extracted"]
        logger.info(
            "Found pre-extracted policy doc for %s / %s",
            claimant_username,
            policy_number,
        )
        return [
            _convert_decimals(
                {
                    "s3_path": doc_entry.get("s3_key", ""),
                    "doc_type": "policy-document",
                    "source": "adjuster_upload",
                    "extracted": extracted,
                }
            )
        ]
    except Exception as e:
        logger.warning("Failed to fetch pre-extracted policy: %s", e)
        return []



def _parse_extraction_results(agent_response: str) -> list:
    """Parse the agent's JSON response into a list of document extractions.

    The agent returns a JSON array either raw or wrapped in a markdown code block.
    """
    text = agent_response.strip()

    # Strip markdown code fences if present
    match = re.search(r"```(?:json)?\s*(\[.*?\])\s*```", text, re.DOTALL)
    if match:
        text = match.group(1)
    else:
        # Try to find a raw JSON array
        start = text.find("[")
        end = text.rfind("]")
        if start != -1 and end != -1:
            text = text[start : end + 1]

    return json.loads(text)


def should_run(claim: dict) -> bool:
    """Always runs — every claim needs document extraction."""
    return True


def invoke(claim_id: str, claim: dict) -> dict:
    """Invoke the document extraction agent via AgentCore Runtime.

    The agent expects { "claim_id": "...", "session_id": "..." } as JSON payload.
    It returns a JSON array of extraction results in its final response.
    """
    session_id = f"orchestrator-{claim_id}-{uuid.uuid4()}"
    payload = json.dumps({"claim_id": claim_id, "session_id": session_id})

    logger.info("Invoking document extraction agent for claim %s", claim_id)

    response = agentcore_client.invoke_agent_runtime(
        agentRuntimeArn=DOCUMENT_EXTRACTION_AGENT_ARN,
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
    logger.info("Document extraction agent response length: %d chars", len(full_response))

    return {"agent_response": full_response}


def update(claim_id: str, result: dict, table, claim: dict | None = None) -> None:
    """Parse extraction results from agent response and write to DynamoDB.

    Sets the documents attribute with extraction data and updates status to document_extracted.
    If a pre-extracted policy document exists (uploaded by adjuster), it is prepended.
    """
    agent_response = result.get("agent_response", "")

    try:
        extractions = _parse_extraction_results(agent_response)
        docs = _convert_decimals(extractions)
        logger.info("Parsed %d document extractions for claim %s", len(docs), claim_id)
    except (json.JSONDecodeError, ValueError) as e:
        logger.error("Failed to parse agent response for claim %s: %s", claim_id, e)
        logger.error("Raw response: %s", agent_response[:500])
        raise ValueError(f"Agent returned invalid extraction JSON: {e}") from e

    # Prepend pre-extracted policy document if available (not used in this deployment)
    pass

    table.update_item(
        Key={"claim_id": claim_id},
        UpdateExpression="SET documents = :docs, #s = :status, updated_at = :ts",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={
            ":docs": docs,
            ":status": "document_extracted",
            ":ts": _now(),
        },
    )
    logger.info("Claim %s: stored %d extractions, status → document_extracted", claim_id, len(docs))
