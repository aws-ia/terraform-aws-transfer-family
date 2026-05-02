import os
from contextlib import contextmanager
from pathlib import Path

from strands import Agent
from strands.models import BedrockModel

from schemas import (
    DOCUMENT_TYPE_DESCRIPTIONS,
    DocumentType,
    PhotoExtraction,
    PolicyDocumentExtraction,
    RepairEstimateExtraction,
)
from tools import list_claim_documents, read_document

GUARDRAIL_ID = os.environ.get("GUARDRAIL_ID", "")
GUARDRAIL_VERSION = os.environ.get("GUARDRAIL_VERSION", "")

PROMPTS_DIR = Path(__file__).parent / "prompts"

EXTRACTION_SCHEMAS = {
    DocumentType.POLICY_DOCUMENT: PolicyDocumentExtraction,
    DocumentType.PHOTO: PhotoExtraction,
    DocumentType.REPAIR_ESTIMATE: RepairEstimateExtraction,
}


def _build_classification_descriptions() -> str:
    """Build document classification descriptions from the schema registry."""
    lines = []
    for doc_type in DocumentType:
        desc = DOCUMENT_TYPE_DESCRIPTIONS.get(doc_type, "No description available.")
        lines.append(f"- {doc_type.value}: {desc}")
    return "\n".join(lines)


def _build_schema_descriptions() -> str:
    """Build a human-readable description of all extraction schemas for the system prompt.

    Each field is described with its expected type and description.  The agent
    is instructed (in the system prompt) to wrap every extracted value in a
    ``{ "value": ..., "confidence": 0.0-1.0 }`` envelope.
    """
    lines = []
    for doc_type, model in EXTRACTION_SCHEMAS.items():
        lines.append(f"\n### {doc_type.value}")
        lines.append(
            "Extract the following fields. For EACH field, return an object with `value` and `confidence` (0.0–1.0):"
        )
        schema = model.model_json_schema()
        for field_name, field_info in schema.get("properties", {}).items():
            desc = field_info.get("description", "")
            field_type = field_info.get("type", "string")
            enum_vals = field_info.get("enum")
            enum_hint = f" (one of: {', '.join(enum_vals)})" if enum_vals else ""
            lines.append(f"  - {field_name} ({field_type}{enum_hint}): {desc}")
    return "\n".join(lines)


def _build_system_prompt() -> str:
    """Load the system prompt template from file and fill in dynamic values."""
    template = (PROMPTS_DIR / "system_prompt.txt").read_text()
    return template.format(
        document_types=", ".join(dt.value for dt in DocumentType),
        classification_descriptions=_build_classification_descriptions(),
        schema_descriptions=_build_schema_descriptions(),
    )


@contextmanager
def get_agent(session_id: str):
    region = os.environ.get("AWS_REGION", os.environ.get("AWS_DEFAULT_REGION", "us-east-1"))

    model_kwargs = {"region_name": region}
    if GUARDRAIL_ID and GUARDRAIL_VERSION:
        model_kwargs.update(
            guardrail_id=GUARDRAIL_ID,
            guardrail_version=GUARDRAIL_VERSION,
            guardrail_trace="enabled",
            guardrail_redact_input=True,
            guardrail_redact_output=False,
        )

    model = BedrockModel(**model_kwargs)

    yield Agent(
        system_prompt=_build_system_prompt(),
        tools=[list_claim_documents, read_document],
        model=model,
    )
