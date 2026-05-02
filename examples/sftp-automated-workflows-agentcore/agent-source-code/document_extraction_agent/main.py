"""Document Extraction Agent — AgentCore Runtime entrypoint."""

import json
import logging
import re
import sys

from bedrock_agentcore import BedrockAgentCoreApp

from agent import get_agent

# Configure logging to stdout so CloudWatch captures it.
# AgentCore Runtime forwards container stdout/stderr to CloudWatch Logs.
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    stream=sys.stdout,
    force=True,
)
logger = logging.getLogger(__name__)

app = BedrockAgentCoreApp()


def _extract_json_array(text: str):
    """Extract a JSON array from the agent's final text output.

    Tries (in order):
      1. A fenced ```json [ ... ] ``` block.
      2. The outermost bracketed span found via bracket counting.
      3. Fallback: json.JSONDecoder().raw_decode scan.

    Returns the parsed list, or None if no valid JSON array was found.
    """
    # 1. Fenced block
    m = re.search(r"```(?:json)?\s*(\[.*?\])\s*```", text, re.DOTALL)
    if m:
        try:
            parsed = json.loads(m.group(1))
            if isinstance(parsed, list):
                return parsed
        except json.JSONDecodeError as e:
            logger.warning("Fenced JSON block failed to parse: %s", e)

    # 2. Outermost [...] span via bracket counting (handles nested arrays)
    start = text.find("[")
    if start != -1:
        depth = 0
        for i in range(start, len(text)):
            ch = text[i]
            if ch == "[":
                depth += 1
            elif ch == "]":
                depth -= 1
                if depth == 0:
                    try:
                        parsed = json.loads(text[start : i + 1])
                        if isinstance(parsed, list):
                            return parsed
                    except json.JSONDecodeError as e:
                        logger.warning("Outermost bracket span failed to parse: %s", e)
                    break

    # 3. raw_decode scan from each [ position
    decoder = json.JSONDecoder()
    for idx in (i for i, c in enumerate(text) if c == "["):
        try:
            parsed, _ = decoder.raw_decode(text[idx:])
            if isinstance(parsed, list):
                return parsed
        except json.JSONDecodeError:
            continue

    return None


def _is_valid_extraction_array(parsed) -> bool:
    """An extraction array must contain dicts with at least s3_path, doc_type, extracted."""
    if not isinstance(parsed, list) or not parsed:
        return False
    required = {"s3_path", "doc_type", "extracted"}
    return all(isinstance(item, dict) and required.issubset(item.keys()) for item in parsed)


@app.entrypoint
def invoke(payload, context=None):
    claim_id = payload.get("claim_id", "")
    session_id = payload.get("session_id", "")
    logger.info("Invoked document_extraction for claim=%s session=%s", claim_id, session_id)

    prompt = (
        f"Process all documents for claim '{claim_id}'. "
        f"List the documents, read each one, classify it, extract structured data, "
        f"and return the final JSON array per the system prompt."
    )

    try:
        with get_agent(session_id=session_id) as agent:
            result = agent(prompt)
            text = str(result)
            logger.info("Agent raw response length: %d chars", len(text))
            logger.debug("Agent raw response: %s", text[:2000])

            parsed = _extract_json_array(text)
            if parsed is None:
                logger.error("No JSON array could be extracted from agent response")
                return {"error": "agent_output_no_json_array", "raw_response": text[:4000]}

            if not _is_valid_extraction_array(parsed):
                logger.error(
                    "Extracted JSON array failed shape validation (got %d items, first=%r)",
                    len(parsed) if isinstance(parsed, list) else 0,
                    parsed[:1] if isinstance(parsed, list) else parsed,
                )
                return {
                    "error": "agent_output_invalid_shape",
                    "raw_response": text[:4000],
                    "parsed_preview": parsed[:3] if isinstance(parsed, list) else parsed,
                }

            logger.info("Returning %d document extraction(s)", len(parsed))
            return parsed
    except Exception:
        logger.exception("document_extraction invocation failed")
        raise


if __name__ == "__main__":
    app.run()
