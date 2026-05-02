"""Claims orchestrator Lambda handler.

Triggered by S3 events (via EventBridge) when a claim ZIP is uploaded.
Extracts the ZIP contents to S3 under a claim-{id}/ prefix, creates a
DynamoDB record, then runs agents sequentially through a pipeline of stages.
"""

import json
import logging
import os
import re
import tempfile
import traceback
import zipfile
from datetime import datetime, timezone
from urllib.parse import unquote_plus

import boto3

from stages import document_extraction, damage_assessment, fraud_detection, classification

logger = logging.getLogger()
logger.setLevel(logging.INFO)

CLAIMS_TABLE = os.environ.get("CLAIMS_TABLE", "")
CLAIMS_BUCKET = os.environ.get("CLAIMS_BUCKET", "")

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(CLAIMS_TABLE)
s3 = boto3.client("s3")

PIPELINE = [
    {"name": "document_extraction", "stage": document_extraction},
    {"name": "damage_assessment", "stage": damage_assessment},
    {"name": "fraud_detection", "stage": fraud_detection},
    {"name": "classification", "stage": classification},
]


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def get_claim(claim_id: str) -> dict:
    response = table.get_item(Key={"claim_id": claim_id})
    return response.get("Item", {})


def create_claim_record(claim_id: str, bucket: str) -> dict:
    """Create the initial claim record in DynamoDB."""
    now = _now()
    item = get_claim(claim_id)
    if item:
        logger.info("Claim %s already exists (status=%s), reprocessing", claim_id, item.get("status"))
    item = {
        "claim_id": claim_id,
        "status": "submitted",
        "created_at": item.get("created_at", now) if item else now,
        "updated_at": now,
        "source_bucket": bucket,
    }
    table.put_item(Item=item)
    return item


def set_error_status(claim_id: str, stage_name: str, error_msg: str) -> None:
    table.update_item(
        Key={"claim_id": claim_id},
        UpdateExpression="SET #s = :status, processing_error = :err, updated_at = :ts",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={
            ":status": "error",
            ":err": {"stage": stage_name, "message": error_msg},
            ":ts": _now(),
        },
    )
    logger.error("Claim %s failed at stage %s: %s", claim_id, stage_name, error_msg)


def extract_zip(bucket: str, key: str, claim_id: str) -> list[str]:
    """Download ZIP from S3, extract contents to claim_id/ prefix, return uploaded keys."""
    uploaded = []
    with tempfile.TemporaryDirectory() as tmp:
        zip_path = os.path.join(tmp, "claim.zip")
        s3.download_file(bucket, key, zip_path)

        with zipfile.ZipFile(zip_path, "r") as zf:
            for name in zf.namelist():
                if name.startswith("__MACOSX") or name.startswith(".") or name.endswith("/"):
                    continue
                # Strip any folder prefix from inside the ZIP
                basename = os.path.basename(name)
                if not basename:
                    continue
                s3_key = f"{claim_id}/{basename}"
                file_path = os.path.join(tmp, basename)
                with zf.open(name) as src, open(file_path, "wb") as dst:
                    dst.write(src.read())
                s3.upload_file(file_path, bucket, s3_key)
                uploaded.append(s3_key)
                logger.info("Extracted %s → s3://%s/%s", name, bucket, s3_key)

    # Delete the original ZIP
    s3.delete_object(Bucket=bucket, Key=key)
    logger.info("Deleted original ZIP: s3://%s/%s", bucket, key)
    return uploaded


def handler(event, context):
    """Lambda entry point. Handles S3/EventBridge events and direct invocation."""
    logger.info("Received event: %s", json.dumps(event))

    detail = event.get("detail", {})
    if detail:
        bucket = detail.get("bucket", {}).get("name", CLAIMS_BUCKET)
        key = unquote_plus(detail.get("object", {}).get("key", ""))

        # Only process ZIP files
        if not key.lower().endswith(".zip"):
            logger.info("Ignoring non-ZIP file: %s", key)
            return {"statusCode": 200, "body": "Ignored — not a ZIP file"}

        # Extract claim_id from filename: claim-1.zip → claim-1
        match = re.match(r"^(?:.*/)?(claim-[^/]+)\.zip$", key)
        if not match:
            logger.info("Ignoring ZIP not matching claim-*.zip: %s", key)
            return {"statusCode": 200, "body": "Ignored — not a claim ZIP"}

        claim_id = match.group(1)
        logger.info("Processing %s from %s", claim_id, key)

        # Extract ZIP contents to claim_id/ prefix
        extract_zip(bucket, key, claim_id)
        create_claim_record(claim_id, bucket)
    else:
        claim_id = event.get("claim_id")

    if not claim_id:
        logger.error("No claim_id resolved from event: %s", event)
        return {"statusCode": 400, "body": "Missing claim_id"}

    logger.info("Starting orchestration for claim %s", claim_id)

    for step in PIPELINE:
        stage_name = step["name"]
        stage = step["stage"]

        try:
            claim = get_claim(claim_id)
            if not claim:
                set_error_status(claim_id, stage_name, "Claim not found")
                return {"statusCode": 404, "body": f"Claim {claim_id} not found"}

            if not stage.should_run(claim):
                logger.info("Skipping stage %s for claim %s (should_run=False)", stage_name, claim_id)
                stage.update(claim_id, {"skipped": True}, table, claim=claim)
                continue

            logger.info("Running stage %s for claim %s", stage_name, claim_id)
            result = stage.invoke(claim_id, claim)
            stage.update(claim_id, result, table, claim=claim)
            logger.info("Completed stage %s for claim %s", stage_name, claim_id)

        except Exception as e:
            set_error_status(claim_id, stage_name, str(e))
            logger.error("Stage %s failed:\n%s", stage_name, traceback.format_exc())
            return {"statusCode": 500, "body": f"Failed at stage {stage_name}: {e}"}

    logger.info("Orchestration complete for claim %s", claim_id)
    return {"statusCode": 200, "body": f"Claim {claim_id} processing complete"}
