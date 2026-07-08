import json
import logging
import os

import boto3

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")
CLAIMS_BUCKET = os.environ.get("CLAIMS_BUCKET", "")
CLAIMS_TABLE = os.environ.get("CLAIMS_TABLE", "")
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff"}
TOOL_NAME_DELIMITER = "___"


def _resolve_tool_name(context):
    """Extract the tool name from the AgentCore Gateway context.

    AgentCore Gateway sends the tool name in context.client_context.custom,
    formatted as target_name + '___' + tool_name. We strip the target prefix.
    """
    try:
        custom = context.client_context.custom
    except AttributeError:
        return ""
    raw = custom.get("bedrockAgentCoreToolName", "")
    if TOOL_NAME_DELIMITER in raw:
        return raw.split(TOOL_NAME_DELIMITER, 1)[1]
    return raw


def lambda_handler(event, context):
    tool_name = _resolve_tool_name(context)
    logger.info("Invoked tool=%s event=%s", tool_name, json.dumps(event))

    # AgentCore Gateway sends the input schema properties directly as the event dict.
    claim_id = event.get("claim_id", "") if isinstance(event, dict) else ""

    if tool_name == "get_claim_data":
        return get_claim_data(claim_id)
    if tool_name == "get_claim_photos":
        return get_claim_photos(claim_id)

    logger.error("Unknown tool name resolved from context: %r", tool_name)
    return {"error": f"Unknown tool: {tool_name}"}


def get_claim_data(claim_id):
    logger.info("get_claim_data claim_id=%s", claim_id)
    try:
        dynamodb = boto3.resource("dynamodb")
        table = dynamodb.Table(CLAIMS_TABLE)
        response = table.get_item(Key={"claim_id": claim_id})
        if "Item" in response:
            return json.loads(json.dumps(response["Item"], default=str))
    except Exception:
        logger.exception("DynamoDB get_item failed for %s — falling back to S3 listing", claim_id)

    # Fallback: list S3 objects under claim prefix
    prefix = f"{claim_id}/"
    resp = s3.list_objects_v2(Bucket=CLAIMS_BUCKET, Prefix=prefix)
    keys = [obj["Key"] for obj in resp.get("Contents", []) if not obj["Key"].endswith("/")]
    return {"claim_id": claim_id, "documents": keys}


def get_claim_photos(claim_id):
    logger.info("get_claim_photos claim_id=%s", claim_id)
    prefix = f"{claim_id}/"
    resp = s3.list_objects_v2(Bucket=CLAIMS_BUCKET, Prefix=prefix)
    photos = []
    for obj in resp.get("Contents", []):
        key = obj["Key"]
        ext = os.path.splitext(key)[1].lower()
        if ext in IMAGE_EXTENSIONS:
            photos.append(key)
    return photos
