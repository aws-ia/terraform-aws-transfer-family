# Simplified Claims Processing Agents

## Overview
The agents have been simplified to focus on the core task: **comparing PDF damage descriptions with actual damage images** to detect inconsistencies.

## Key Changes

### 1. **Damage Validation Agent** (formerly Fraud Validation Agent)
**Purpose**: Compare the damage description in the PDF with the actual damage shown in the image.

**What it does**:
- Receives damage description from extracted entities (damage_type, severity, description)
- Retrieves the damage image from S3
- Uses Claude 3.5 Sonnet with vision to compare description vs. actual damage
- Returns: `consistent` (true/false), `confidence` (0-1), and `reasoning`

**Example**:
- PDF says: "Minor scratches on bumper"
- Image shows: Totaled vehicle with severe front-end damage
- Result: `consistent: false`, reasoning: "PDF describes minor damage but image shows vehicle is totaled"

### 2. **Workflow Orchestrator**
**Updated to**:
1. Extract entities from PDF
2. Validate damage consistency (compare PDF description with image)
3. Insert enriched data (with validation results) into DynamoDB
4. Generate summary report

**Field names changed**:
- `fraud_detected` → `damage_consistent`
- `fraud_confidence` → `validation_confidence`
- `fraud_reason` → `validation_reasoning`

### 3. **Summary Report Agent**
**Updated to**:
- Report on "Damage Validation" instead of "Fraud Analysis"
- Show whether description matches image
- Provide clear recommendations based on consistency

### 4. **Other Agents** (unchanged)
- **Entity Extraction Agent**: Still extracts claim data from PDF
- **Database Insertion Agent**: Still stores results in DynamoDB

## Workflow

```
1. PDF Upload → Entity Extraction
   ↓
   Extracts: claim_number, damage_type, severity, description, etc.

2. Entities + Image → Damage Validation
   ↓
   Compares PDF description with actual image
   Returns: damage_consistent, validation_confidence, validation_reasoning

3. Enriched Entities → Database Insertion
   ↓
   Stores all data including validation results

4. Enriched Entities → Summary Report
   ↓
   Generates human-readable report with recommendation
```

## Testing with claim-1 Data

The `data/claim-1/` folder contains:
- `car_damage_claim_report.pdf` - Claim document with damage description
- `claim-1.png` - Actual damage photo

Use this to test the validation logic. If the PDF describes minor damage but the image shows a totaled car, the agent should detect this inconsistency.

## Model Used

**Damage Validation Agent**: `anthropic.claude-3-5-sonnet-20241022-v2:0`
- This model has vision capabilities to analyze images
- Temperature: 0.1 (for consistent, deterministic results)
- Max tokens: 500 (sufficient for validation response)

## Expected Output Format

```json
{
  "claim_number": "CL20251006-AUTO789",
  "damage_type": "Front-end collision",
  "severity": "Minor",
  "description": "Small scratches on bumper",
  "damage_consistent": false,
  "validation_confidence": 0.95,
  "validation_reasoning": "The PDF describes minor scratches, but the image shows severe front-end damage with the vehicle appearing totaled. This is a significant inconsistency."
}
```

## Deployment

The agents are deployed as Docker containers to ECR and run on Bedrock AgentCore. No changes to the Terraform infrastructure are needed - just rebuild and redeploy the agent images.
