"""Damage Assessment Agent — AgentCore Runtime entrypoint."""

import json
import logging
import re
import sys

from bedrock_agentcore import BedrockAgentCoreApp

from agent import get_agent

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    stream=sys.stdout,
    force=True,
)
logger = logging.getLogger(__name__)

app = BedrockAgentCoreApp()


@app.entrypoint
def invoke(payload, context=None):
    claim_id = payload.get("claim_id", "")
    session_id = payload.get("session_id", "")
    logger.info("Invoked damage_assessment for claim=%s session=%s", claim_id, session_id)

    prompt = (
        f"Assess damage for claim '{claim_id}'. "
        f"Read the claim data, identify photos, analyze each photo for damage, "
        f"research repair costs, and return a structured damage assessment with cost estimate."
    )

    try:
        with get_agent(session_id=session_id) as agent:
            result = agent(prompt)
            text = str(result)
            logger.info("Agent raw response length: %d chars", len(text))

            match = re.search(r"\{.*\}", text, re.DOTALL)
            if match:
                try:
                    return json.loads(match.group(0))
                except json.JSONDecodeError as e:
                    logger.warning("JSON parse failed: %s", e)
            logger.error("Could not extract JSON object from response")
            return {"error": "agent_output_no_json_object", "raw_response": text[:4000]}
    except Exception:
        logger.exception("damage_assessment invocation failed")
        raise


if __name__ == "__main__":
    app.run()
