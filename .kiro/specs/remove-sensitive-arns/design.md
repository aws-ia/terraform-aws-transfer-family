# Design Document

## Overview

This design outlines the approach for removing sensitive AWS ARN data from documentation files to address the Code Defender security vulnerability. The solution involves systematically replacing real AWS account IDs and resource identifiers with standardized placeholder values while maintaining the educational and functional value of the documentation.

## Architecture

### Affected Components

The remediation targets three specific files containing sensitive ARN data:

1. **modules/custom-idp/README.md** - Main module documentation
2. **modules/custom-idp/examples/enterprise/README.md** - Enterprise example documentation  
3. **modules/custom-idp/examples/enterprise/terraform.tfvars.example** - Configuration template

### Current State Analysis

The sensitive ARN pattern identified is:
```
arn:aws:kms:us-east-1:123456789012:key/[SENSITIVE-KEY-ID]
```

This appears in three contexts:
- Configuration examples in README files
- Terraform variable examples
- Code snippets demonstrating KMS key usage

## Components and Interfaces

### File Processing Component

**Purpose**: Systematically replace sensitive ARN data with placeholder values

**Interface**:
- Input: Files containing sensitive ARN data
- Output: Sanitized files with placeholder ARNs
- Method: String replacement with validation

### Placeholder Generation Component

**Purpose**: Generate consistent, valid placeholder ARN formats

**Standards**:
- Account ID: Use existing placeholder "123456789012" (already in use)
- KMS Key ID: Generate generic UUID format for examples
- Region: Keep as "us-east-1" for consistency
- Service: Maintain "kms" service identifier

## Data Models

### ARN Structure Model

```
arn:aws:service:region:account-id:resource-type/resource-id
```

### Placeholder ARN Pattern

```
arn:aws:kms:us-east-1:123456789012:key/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
```

Where X represents placeholder characters that clearly indicate example usage.

## Error Handling

### Validation Strategy

1. **Pre-processing Validation**
   - Verify files exist and are readable
   - Confirm ARN patterns match expected format
   - Backup original content for rollback capability

2. **Post-processing Validation**
   - Ensure all sensitive ARNs are replaced
   - Verify placeholder ARNs maintain valid AWS ARN structure
   - Confirm documentation readability is preserved

3. **Rollback Strategy**
   - Maintain original file content for emergency rollback
   - Validate changes before committing
   - Test documentation rendering after changes

## Testing Strategy

### Security Testing

1. **Pattern Detection Testing**
   - Verify Code Defender no longer flags sensitive data
   - Scan for any remaining real account IDs
   - Validate no new sensitive patterns are introduced

2. **Functional Testing**
   - Ensure documentation remains clear and useful
   - Verify Terraform examples maintain proper syntax
   - Confirm placeholder ARNs follow AWS ARN format standards

3. **Regression Testing**
   - Test that module functionality is unaffected
   - Verify example configurations remain valid
   - Ensure documentation generation tools still work

### Implementation Approach

#### Phase 1: Immediate Remediation
- Replace the specific sensitive ARN with placeholder values
- Use consistent placeholder format across all files
- Maintain context and educational value

#### Phase 2: Validation
- Run Code Defender scan to confirm remediation
- Review all changes for completeness
- Test documentation rendering and clarity

#### Phase 3: Prevention
- Document placeholder standards for future contributions
- Consider adding validation checks to prevent future sensitive data commits

## Security Considerations

### Data Sanitization
- Ensure complete removal of real AWS account information
- Use clearly identifiable placeholder values
- Maintain ARN format validity for educational purposes

### Documentation Security
- Preserve instructional value while removing sensitive data
- Use consistent placeholder patterns across all documentation
- Ensure examples remain functional for users

### Compliance
- Meet Code Defender security requirements
- Follow AWS documentation best practices for examples
- Maintain repository security standards