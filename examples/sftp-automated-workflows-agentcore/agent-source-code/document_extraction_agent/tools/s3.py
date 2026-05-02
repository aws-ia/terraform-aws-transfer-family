import base64
import io
import os

import boto3
from pypdf import PdfReader
from strands import tool

CLAIMS_BUCKET = os.environ.get("CLAIMS_BUCKET", "")

_region = os.environ.get("AWS_REGION", os.environ.get("AWS_DEFAULT_REGION"))
s3_client = boto3.client("s3", region_name=_region)

# File extensions that should be returned as extracted text rather than base64
TEXT_EXTRACTABLE = {".pdf"}
# Extensions the model can handle natively as base64 (images)
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff"}


def _extract_pdf_text(data: bytes) -> str:
    """Extract text content from a PDF file."""
    reader = PdfReader(io.BytesIO(data))
    pages = []
    for i, page in enumerate(reader.pages):
        text = page.extract_text() or ""
        if text.strip():
            pages.append(f"--- Page {i + 1} ---\n{text}")
    return "\n\n".join(pages)


@tool
def list_claim_documents(claim_id: str) -> list[str]:
    """List all document keys in S3 under the claim prefix.

    Args:
        claim_id: The claim identifier, used as the S3 prefix.

    Returns:
        A list of S3 object keys found under the claim prefix.
    """
    prefix = f"{claim_id}/"
    response = s3_client.list_objects_v2(Bucket=CLAIMS_BUCKET, Prefix=prefix)
    contents = response.get("Contents", [])
    return [obj["Key"] for obj in contents if not obj["Key"].endswith("/")]


@tool
def read_document(s3_key: str) -> str:
    """Download a document from S3 and return its content.

    For PDFs, extracts and returns the text content directly.
    For images, returns base64-encoded content for multimodal processing.
    For other files (HTML, text), returns the decoded text content.

    Args:
        s3_key: The S3 object key to download.

    Returns:
        Document content as text (for PDFs/HTML/text) or base64-encoded string (for images).
    """
    response = s3_client.get_object(Bucket=CLAIMS_BUCKET, Key=s3_key)
    body = response["Body"].read()

    ext = os.path.splitext(s3_key)[1].lower()

    if ext in TEXT_EXTRACTABLE:
        return _extract_pdf_text(body)

    if ext in IMAGE_EXTENSIONS:
        return base64.b64encode(body).decode("utf-8")

    # HTML, text, and other readable formats — return as decoded text
    try:
        return body.decode("utf-8")
    except UnicodeDecodeError:
        return base64.b64encode(body).decode("utf-8")
