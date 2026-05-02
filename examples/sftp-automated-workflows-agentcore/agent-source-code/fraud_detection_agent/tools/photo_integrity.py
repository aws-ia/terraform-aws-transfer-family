"""Bedrock vision tool for analyzing photo integrity.

Downloads a claim photo from S3 and sends it to Bedrock Claude with a
configurable vision prompt (loaded from prompts/photo_integrity_prompt.txt).
The prompt defines what artifacts to look for — swap the file to customize
the analysis for different fraud detection scenarios.
"""

import base64
import json
import logging
import os
import re
from functools import lru_cache
from pathlib import Path

import boto3
from strands import tool

logger = logging.getLogger(__name__)

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff"}

MEDIA_TYPE_MAP = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".gif": "image/gif",
    ".webp": "image/webp",
    ".bmp": "image/bmp",
    ".tiff": "image/tiff",
}

PROMPTS_DIR = Path(__file__).parent.parent / "prompts"

VISION_MODEL_ID = os.environ.get("VISION_MODEL_ID", "global.anthropic.claude-sonnet-4-6")


def _load_integrity_prompt() -> str:
    return (PROMPTS_DIR / "photo_integrity_prompt.txt").read_text()


def _region():
    return os.environ.get("AWS_REGION", os.environ.get("AWS_DEFAULT_REGION", "us-east-1"))


@lru_cache
def _s3_client():
    return boto3.client("s3", region_name=_region())


@lru_cache
def _bedrock_client():
    return boto3.client("bedrock-runtime", region_name=_region())


@tool
def analyze_photo_integrity(s3_path: str, claim_id: str) -> dict:
    """Download a claim photo from S3 and check for manipulation artifacts.

    Uses Bedrock vision to detect lighting mismatches, copy-paste artifacts,
    resolution inconsistencies, and other signs of digital manipulation.

    Args:
        s3_path: The S3 object key for the photo.
        claim_id: The claim identifier (used for access scoping).

    Returns:
        A dict with manipulation_detected, confidence, detail, and
        artifacts_found fields.
    """
    claims_bucket = os.environ.get("CLAIMS_BUCKET", "")

    logger.info("analyze_photo_integrity called: s3_path=%s, claim_id=%s, bucket=%s", s3_path, claim_id, claims_bucket)

    if not claims_bucket:
        return {"error": "CLAIMS_BUCKET environment variable not set"}

    if not s3_path.startswith(f"{claim_id}/"):
        return {"error": f"Photo path {s3_path} does not belong to claim {claim_id}"}

    ext = os.path.splitext(s3_path)[1].lower()
    if ext not in IMAGE_EXTENSIONS:
        return {"error": f"Unsupported image format: {ext}"}

    try:
        response = _s3_client().get_object(Bucket=claims_bucket, Key=s3_path)
        image_bytes = response["Body"].read()
    except Exception as e:
        return {"error": f"Failed to download photo from S3: {e}", "photo_s3_path": s3_path}

    media_type = MEDIA_TYPE_MAP.get(ext, "image/jpeg")
    image_b64 = base64.b64encode(image_bytes).decode("utf-8")

    body = json.dumps(
        {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 1024,
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": media_type,
                                "data": image_b64,
                            },
                        },
                        {"type": "text", "text": _load_integrity_prompt()},
                    ],
                }
            ],
        }
    )

    try:
        result = _bedrock_client().invoke_model(
            modelId=VISION_MODEL_ID,
            contentType="application/json",
            accept="application/json",
            body=body,
        )
    except Exception as e:
        return {"error": f"Bedrock invoke_model failed: {e}", "photo_s3_path": s3_path}

    text = json.loads(result["body"].read()).get("content", [{}])[0].get("text", "{}")

    try:
        analysis = json.loads(text)
    except json.JSONDecodeError:
        match = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", text, re.DOTALL)
        if match:
            analysis = json.loads(match.group(1))
        else:
            analysis = {"error": "Failed to parse vision model response", "raw": text}

    analysis["photo_s3_path"] = s3_path
    return analysis
