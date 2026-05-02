"""Default fraud detection rules — pure data, no handler functions.

Each rule defines what the LLM should check in the claim data. Rules can cover
any type of anomaly detection: date validation, financial thresholds, document
consistency, coverage verification, or custom business logic. The descriptions
are verbose so the LLM knows exactly which fields to compare and what constitutes
a flag.

On startup, these can be overridden by rules fetched from the gateway
(get_fraud_rules tool) for per-insurer customization. Add, remove, or modify
rules here to change what the agent checks — no code changes needed elsewhere.
"""

FRAUD_RULES = [
    {
        "id": "policy_validity",
        "enabled": True,
        "weight": 0.20,
        "description": (
            "Policy must be active on incident date. Compare the policy effective "
            "and expiry dates against the incident date. Flag if incident date is "
            "outside the policy period."
        ),
    },
    {
        "id": "coverage_mismatch",
        "enabled": True,
        "weight": 0.20,
        "description": (
            "Claimed damage type must be covered by the policy. Compare damage "
            "types from the damage assessment against specific coverage types listed "
            "in the extracted policy document. If the policy only lists a general "
            "coverage category (e.g. 'Homeowners') without an itemized list of "
            "covered damage types, set triggered=true with detail='insufficient "
            "granularity — policy lists general coverage type only, cannot verify "
            "specific damage type is covered'."
        ),
    },
    {
        "id": "amount_exceeds_coverage",
        "enabled": True,
        "weight": 0.15,
        "description": (
            "Claimed amount must not exceed the policy coverage limit. Compare "
            "the claimed_amount field against the coverage limit from the extracted "
            "policy document. Flag if claimed amount exceeds the limit."
        ),
    },
    {
        "id": "estimate_deviation",
        "enabled": True,
        "weight": 0.10,
        "description": (
            "Repair estimate total should be reasonably close to the damage "
            "assessment cost estimate. Compare the repair estimate total from "
            "document extraction against the damage assessment cost_estimate.total."
        ),
        "params": {"threshold": 2.0},
    },
    {
        "id": "date_inconsistency",
        "enabled": True,
        "weight": 0.10,
        "description": (
            "Document dates must be logically consistent. The repair estimate date "
            "must be after the incident date. The policy issue date must be before "
            "the incident date. Flag any date ordering violations."
        ),
    },
    {
        "id": "duplicate_line_items",
        "enabled": True,
        "weight": 0.10,
        "description": (
            "Repair estimate should not contain duplicate line items. Check the "
            "extracted repair estimate line items for entries with identical or "
            "near-identical descriptions. Flag if duplicates are found."
        ),
    },
    {
        "id": "photo_manipulation",
        "enabled": True,
        "weight": 0.15,
        "description": (
            "Photos must not show signs of digital manipulation. For EVERY photo "
            "in the claim, call `analyze_photo_integrity(s3_path, claim_id)` and "
            "check the result. Flag if any photo shows manipulation artifacts "
            "(cloning, splicing, metadata inconsistencies, AI generation). "
            "If multiple photos are manipulated, this rule triggers once with "
            "detail listing all affected photos. If no photos exist, set "
            "triggered=false with detail='no photos to analyze'."
        ),
    },
]

# Total weights: 0.20 + 0.20 + 0.15 + 0.10 + 0.10 + 0.10 + 0.15 = 1.00
