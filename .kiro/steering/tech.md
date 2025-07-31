# Technology Stack & Build System

## Core Technologies

- **Terraform**: >= 1.5 (Infrastructure as Code)
- **AWS Provider**: >= 5.95.0
- **Target Platform**: AWS Cloud Services

## Key AWS Services Used

- AWS Transfer Family (SFTP servers)
- Amazon S3 (file storage backend)
- AWS Route53 (DNS management)
- CloudWatch Logs (logging and monitoring)
- AWS IAM (identity and access management)
- AWS VPC (networking for VPC endpoints)

## Project Structure

This is a **Terraform module** with a modular architecture:
- Root module: Main transfer server configuration
- Sub-modules: `transfer-server`, `transfer-users`, `custom-idp`
- Examples: Working implementations in `examples/` directory

## Common Commands

### Development & Testing
```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan changes
terraform plan

# Apply changes
terraform apply

# Run Terraform tests
terraform test

# Format code
terraform fmt -recursive
```

### Static Analysis & Linting
```bash
# Run all static tests (includes terraform fmt, validate, tflint, tfsec, checkov)
./.project_automation/static_tests/static_tests.sh

# Run functional tests
./.project_automation/functional_tests/functional_tests.sh
```

## Code Quality Tools

- **terraform fmt**: Code formatting
- **terraform validate**: Syntax validation
- **tflint**: Terraform linting
- **tfsec**: Security scanning
- **checkov**: Policy as code scanning
- **terraform-docs**: Documentation generation

## Testing Framework

- **Terraform Test**: Native testing with `.tftest.hcl` files
- **Example-based testing**: Tests run against example configurations
- **Multi-scenario testing**: Both PUBLIC and VPC endpoint configurations