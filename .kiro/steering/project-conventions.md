---
inclusion: manual
---
# Project Conventions — terraform-aws-transfer-family

## Overview

Terraform module for AWS Transfer Family. Uses native Terraform tests (`terraform test`). Test definitions are in `tests/01_mandatory.tftest.hcl` and reference the `examples/` directories. Go/Terratest is not used.

## Required Tooling and Expected Versions

The CI pipeline pins specific tool versions in `.project_automation/static_tests/Dockerfile`. Local installations should be version-compatible. If a tool is already installed, verify the version meets the minimum requirement.

| Tool | Expected Version | Source of Truth | Install (macOS) |
|---|---|---|---|
| Terraform | >= 1.10.x | `static_tests/Dockerfile` (1.10.5), `functional_tests/Dockerfile` (1.10.0) | `brew install terraform` |
| tflint | v0.58.0 | `static_tests/Dockerfile` | `brew install tflint` |
| tflint-ruleset-aws | v0.27.0 | `.config/.tflint.hcl` plugin block | Auto-installed via `tflint --init --config .config/.tflint.hcl` |
| terraform-docs | v0.20.0 | `static_tests/Dockerfile` | `brew install terraform-docs` |
| tfsec | latest available | `static_tests/Dockerfile` | `brew install tfsec` |
| checkov | latest | `static_tests/Dockerfile` (`pip3 install checkov`) | `pip install checkov` |
| mdl | latest | `static_tests/Dockerfile` (`gem install mdl`) | `gem install mdl` |
| pre-commit | >= 2.6.0 | `.pre-commit-config.yaml` (`minimum_pre_commit_version`) | `pip install pre-commit` |

Note: The Dockerfile installs tflint-ruleset-aws at v0.22.1, but `.config/.tflint.hcl` declares v0.27.0. The `.tflint.hcl` config is the effective source of truth when running `tflint --init` locally.

Verification commands:
```bash
terraform --version
tflint --version
terraform-docs --version
tfsec --version
checkov --version
mdl --version
pre-commit --version
```

## Static Tests Pipeline

The pre-commit hook executes `.project_automation/static_tests/static_tests.sh` (skipping the first 5 lines of path setup, using local paths instead). The following checks run in order:

1. `terraform init` + `terraform validate`
2. `tflint` — config: `.config/.tflint.hcl`
3. `tfsec` — config: `.config/.tfsec.yml`, custom checks: `.config/.tfsec/`
4. `checkov` — config: `.config/.checkov.yml`
5. `mdl` — lints `.header.md` and `examples/*/.header.md`, config: `.config/.mdlrc`
6. `terraform-docs` — generates `README.md` files, config: `.config/.terraform-docs.yaml`

All checks must pass for the pre-commit hook and CI to succeed.

## Pre-Commit Hook Setup

```bash
GIT_CONFIG=/dev/null pre-commit install
```

Defined in `.pre-commit-config.yaml`. Runs the full static test suite on every commit. The `GIT_CONFIG=/dev/null` flag prevents global git config from interfering with the hook.

## Testing

- Framework: native Terraform tests (`terraform test`), not Go/Terratest
- Test file: `tests/01_mandatory.tftest.hcl`
- Tests execute `plan` and `apply` against `examples/` directories
- Test-specific variables: `tests/*.auto.tfvars`
- CI functional tests: `.project_automation/functional_tests/functional_tests.sh`
- The `go.mod`/`go.sum` entries in `.gitignore` are legacy and not used

## Config Files

Tool configurations are in `.config/`:

| File | Purpose |
|---|---|
| `.config/.tflint.hcl` | tflint rules and AWS plugin declaration |
| `.config/.tfsec.yml` | tfsec scan configuration |
| `.config/.tfsec/*.json` | Custom tfsec check definitions |
| `.config/.checkov.yml` | Checkov settings (scoped to Terraform framework, skips non-AWS checks) |
| `.config/.terraform-docs.yaml` | terraform-docs output format and README generation |
| `.config/.mdlrc` | Markdown lint rules (disables MD007, MD013, MD029) |

## Known Tech Debt

- tfsec has been deprecated and merged into [Trivy](https://github.com/aquasecurity/tfsec) by Aqua Security. This project still uses the legacy tfsec binary in the static tests script and Dockerfile. Migration to `trivy config` has not been completed. Any migration should be coordinated across the full pipeline (Dockerfile, static_tests.sh, and .config/.tfsec/).
- The static tests Dockerfile pins tflint-ruleset-aws at v0.22.1 while `.config/.tflint.hcl` declares v0.27.0. These should be aligned.
