"""Default classification rules — threshold-based routing, no weighted scoring.

The fraud detection agent already produces a weighted risk_score. The classification
agent reads that score plus other claim data and routes to one of three outcomes:
approved, requires_review, or rejected. Each rule is a condition check — if ANY
rejection condition triggers, the outcome is rejected. If ANY review condition
triggers (and no rejection), the outcome is requires_review. Otherwise, approved.

On startup, these can be overridden by rules fetched from the gateway
(get_classification_rules tool) for per-insurer customization.
"""

CLASSIFICATION_RULES = {
    "approved": {
        "description": "Claim is clean and eligible for automatic settlement.",
        "conditions": [
            {
                "id": "low_fraud_risk",
                "description": (
                    "fraud_assessment.risk_score < 0.25 — the fraud detection agent rated this claim as low risk."
                ),
            },
            {
                "id": "high_damage_confidence",
                "description": ("ALL items in damage_assessment.damage_items have confidence >= 0.8."),
            },
            {
                "id": "within_coverage",
                "description": ("claimed_amount <= coverage limit from the extracted policy document."),
            },
            {
                "id": "no_policy_violations",
                "description": (
                    "fraud_assessment.flags does NOT contain a triggered policy_validity rule (triggered=true)."
                ),
            },
            {
                "id": "no_photo_manipulation",
                "description": (
                    "fraud_assessment.flags does NOT contain a triggered photo_manipulation rule (triggered=true)."
                ),
            },
        ],
    },
    "requires_review": {
        "description": (
            "Claim needs adjuster verification due to complexity or moderate "
            "risk flags. ANY of these conditions being true triggers review."
        ),
        "conditions": [
            {
                "id": "moderate_fraud_risk",
                "description": ("fraud_assessment.risk_score is between 0.25 and 0.60 (inclusive on both ends)."),
            },
            {
                "id": "low_damage_confidence",
                "description": ("ANY item in damage_assessment.damage_items has confidence < 0.8."),
            },
            {
                "id": "estimate_deviation",
                "description": (
                    "fraud_assessment.flags contains a triggered estimate_deviation rule (triggered=true)."
                ),
            },
            {
                "id": "coverage_mismatch",
                "description": (
                    "fraud_assessment.flags contains a triggered "
                    "coverage_mismatch rule (triggered=true) — e.g. "
                    "insufficient granularity in policy coverage."
                ),
            },
            {
                "id": "high_claimed_amount",
                "description": ("claimed_amount exceeds the configurable threshold."),
                "params": {"threshold_usd": 10000},
            },
        ],
    },
    "rejected": {
        "description": (
            "Claim has clear policy violations or high fraud indicators "
            "requiring investigation. ANY of these conditions being true "
            "triggers rejection."
        ),
        "conditions": [
            {
                "id": "high_fraud_risk",
                "description": "fraud_assessment.risk_score >= 0.60.",
            },
            {
                "id": "policy_violation",
                "description": (
                    "fraud_assessment.flags contains a triggered "
                    "policy_validity rule (triggered=true) — expired or "
                    "invalid policy."
                ),
            },
            {
                "id": "photo_manipulation_detected",
                "description": (
                    "fraud_assessment.flags contains a triggered "
                    "photo_manipulation rule (triggered=true) with "
                    "confidence >= 0.7."
                ),
            },
            {
                "id": "exceeds_coverage",
                "description": (
                    "fraud_assessment.flags contains a triggered amount_exceeds_coverage rule (triggered=true)."
                ),
            },
        ],
    },
}
