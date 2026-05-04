from decimal import Decimal
from enum import StrEnum
from typing import Any

from pydantic import BaseModel, Field


class DocumentType(StrEnum):
    PHOTO = "photo"
    POLICY_DOCUMENT = "policy-document"
    REPAIR_ESTIMATE = "repair-estimate"
    SUBMISSION_FORM = "submission-form"


# Maps each document type to a human-readable description for the agent prompt.
DOCUMENT_TYPE_DESCRIPTIONS: dict[str, str] = {
    DocumentType.PHOTO: ("Images showing damage to vehicles, property, or other insured items."),
    DocumentType.POLICY_DOCUMENT: (
        "Insurance policy documents containing coverage details, limits, and beneficiary info."
    ),
    DocumentType.REPAIR_ESTIMATE: ("Cost assessments from repair shops with itemized repairs and totals."),
    DocumentType.SUBMISSION_FORM: (
        "Claim submission forms filled out by the claimant describing the incident, "
        "identifying the claimant and policy, and stating the claimed amount. "
        "Typically a signed one- or two-page form that accompanies the supporting documents."
    ),
}


class CoverageType(StrEnum):
    LIABILITY = "liability"
    COLLISION = "collision"
    COMPREHENSIVE = "comprehensive"
    UNINSURED_MOTORIST = "uninsured_motorist"
    PERSONAL_INJURY = "personal_injury"
    PROPERTY_DAMAGE = "property_damage"
    HOMEOWNERS = "homeowners"
    RENTERS = "renters"
    FLOOD = "flood"
    FIRE = "fire"


class DamageSeverity(StrEnum):
    MINOR = "minor"
    MODERATE = "moderate"
    SEVERE = "severe"
    TOTAL_LOSS = "total_loss"


# --- Extraction models per document type ---


class SubmissionFormExtraction(BaseModel):
    claimant_name: str = Field(description="Full name of the person filing the claim")
    claimant_email: str | None = Field(default=None, description="Claimant contact email, if provided on the form")
    claimant_phone: str | None = Field(default=None, description="Claimant contact phone, if provided on the form")
    policy_number: str = Field(description="Policy number referenced on the submission form")
    incident_date: str = Field(description="Date the incident occurred in YYYY-MM-DD format")
    incident_description: str = Field(
        description="Claimant's narrative description of what happened during the incident"
    )
    claimed_amount: Decimal = Field(description="Total dollar amount the claimant is requesting")


class PolicyDocumentExtraction(BaseModel):
    policy_number: str = Field(description="The policy number")
    policyholder_name: str = Field(description="Full name of the policyholder")
    coverage_type: CoverageType = Field(description="Type of insurance coverage")
    coverage_limit: Decimal = Field(description="Maximum coverage amount in dollars")
    deductible: Decimal = Field(description="Deductible amount in dollars")
    effective_date: str = Field(description="Policy start date in YYYY-MM-DD format")
    expiration_date: str = Field(description="Policy end date in YYYY-MM-DD format")
    beneficiaries: list[str] = Field(default_factory=list, description="List of beneficiary names")
    additional_notes: str | None = Field(default=None, description="Any additional relevant details")


class PhotoExtraction(BaseModel):
    damage_type: str = Field(description="Type of damage observed, e.g. vehicle, property, water")
    severity: DamageSeverity = Field(description="Severity of the damage")
    description: str = Field(description="Detailed description of the visible damage")
    affected_areas: list[str] = Field(description="List of affected areas, e.g. front_bumper, roof, floor")


class RepairLineItem(BaseModel):
    description: str = Field(description="Description of the repair item or service")
    cost: Decimal = Field(description="Cost of this line item in dollars")


class RepairEstimateExtraction(BaseModel):
    shop_name: str = Field(description="Name of the repair shop")
    estimate_date: str = Field(description="Date of the estimate in YYYY-MM-DD format")
    line_items: list[RepairLineItem] = Field(description="Itemized list of repairs and costs")
    total_cost: Decimal = Field(description="Total estimated repair cost in dollars")
    labor_hours: Decimal | None = Field(default=None, description="Estimated labor hours")


# --- Claim-level models ---


class ClaimDocument(BaseModel):
    s3_path: str = Field(description="S3 path where the document is stored")
    doc_type: DocumentType = Field(description="Type of document")
    extracted: dict[str, Any] = Field(description="Extracted data from the document")


class ClaimRecord(BaseModel):
    claim_id: str = Field(description="Unique claim identifier")
    documents: list[ClaimDocument] = Field(default_factory=list, description="List of processed documents")
