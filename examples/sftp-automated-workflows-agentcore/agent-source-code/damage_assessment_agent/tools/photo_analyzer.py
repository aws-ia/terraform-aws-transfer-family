"""Bedrock multimodal vision tool for analyzing damage photos."""

import base64
import json
import os
import re
from functools import lru_cache

import boto3
from strands import tool

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff"}

VISION_PROMPT = """\
Analyze this image for insurance damage assessment. Provide a structured analysis:

1. **damage_type**: Classify the primary damage type \
(water_damage, fire_damage, wind_damage, collision, vandalism, theft, other)
2. **severity**: Rate severity (minor, moderate, severe, total_loss)
3. **affected_area**: Describe the specific area/component affected
4. **pre_existing**: Is there evidence of pre-existing damage? (true/false)
5. **confidence**: Your confidence in this assessment (0.0 to 1.0)
6. **description**: Detailed description of the visible damage

Respond ONLY with a JSON object matching this schema. Do NOT invent damage not visible in the photo.
If the image is unclear, set confidence low and note uncertainty in the description."""


def _region():
    return os.environ.get("AWS_REGION", os.environ.get("AWS_DEFAULT_REGION", "us-east-1"))


@lru_cache
def _s3_client():
    return boto3.client("s3", region_name=_region())


@lru_cache
def _bedrock_client():
    return boto3.client("bedrock-runtime", region_name=_region())


@tool
def analyze_photo(s3_path: str, claim_id: str) -> dict:
    """Download a photo from S3 and analyze it for damage using Bedrock vision.

    Sends the image to Claude with a structured vision prompt to classify
    damage type, assess severity, and check for pre-existing damage.

    Args:
        s3_path: The S3 object key for the photo.
        claim_id: The claim identifier (used for access scoping).

    Returns:
        A dict with damage_type, severity, affected_area, pre_existing,
        confidence, and description fields.
    """
    claims_bucket = os.environ.get("CLAIMS_BUCKET", "")

    if not s3_path.startswith(f"{claim_id}/"):
        return {"error": f"Photo path {s3_path} does not belong to claim {claim_id}"}

    response = _s3_client().get_object(Bucket=claims_bucket, Key=s3_path)
    image_bytes = response["Body"].read()

    ext = os.path.splitext(s3_path)[1].lower()
    if ext not in IMAGE_EXTENSIONS:
        return {"error": f"Unsupported image format: {ext}"}

    media_type_map = {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".gif": "image/gif",
        ".webp": "image/webp",
        ".bmp": "image/bmp",
        ".tiff": "image/tiff",
    }
    media_type = media_type_map.get(ext, "image/jpeg")

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
                        {"type": "text", "text": VISION_PROMPT},
                    ],
                }
            ],
        }
    )

    response = _bedrock_client().invoke_model(
        modelId=os.environ.get("VISION_MODEL_ID", "global.anthropic.claude-sonnet-4-6"),
        contentType="application/json",
        accept="application/json",
        body=body,
    )

    result = json.loads(response["body"].read())
    text = result.get("content", [{}])[0].get("text", "{}")

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
