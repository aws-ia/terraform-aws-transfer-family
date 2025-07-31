# Project Structure & Organization

## Root Module Structure

```
├── main.tf              # Primary module logic and resources
├── variables.tf         # Input variable definitions
├── outputs.tf           # Output value definitions
├── versions.tf          # Terraform and provider version constraints
└── README.md           # Auto-generated documentation
```

## Key Directories

### `/modules/`
Contains reusable sub-modules:
- `transfer-server/`: Core Transfer Family server module
- `transfer-users/`: User management module
- `custom-idp/`: Custom identity provider with Lambda functions

### `/examples/`
Working example implementations:
- `basic/`: Simple SFTP server setup
- `sftp-public-endpoint-service-managed-S3/`: Public endpoint configuration
- `sftp-internet-facing-vpc-endpoint-service-managed-S3/`: VPC endpoint setup

### `/tests/`
Terraform test files (`.tftest.hcl` format)

### `/.project_automation/`
CI/CD automation scripts:
- `static_tests/`: Linting, formatting, security scanning
- `functional_tests/`: Integration testing
- `publication/`: Release automation

### `/.config/`
Tool configurations:
- `.tflint.hcl`: TFLint rules
- `.tfsec.yml`: TFSec security policies
- `.checkov.yml`: Checkov policy scanning
- `.terraform-docs.yaml`: Documentation generation

## File Naming Conventions

- **Terraform files**: Use standard names (`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`)
- **Test files**: `*.tftest.hcl` in `/tests/` directory
- **Example directories**: Descriptive names reflecting the use case
- **Module directories**: Kebab-case naming (e.g., `custom-idp`)

## Code Organization Patterns

### Variable Validation
All variables include validation blocks with clear error messages

### Resource Naming
- Use descriptive resource names
- Include validation checks for configuration consistency
- Use `locals` for complex logic and reusable values

### Documentation
- Auto-generated README.md using terraform-docs
- Inline comments for complex logic
- Header files (`.header.md`) for custom documentation sections

### Security Practices
- Checkov skip comments with justification (e.g., `#checkov:skip=CKV_AWS_164`)
- Security policy validation in variables
- Default secure configurations