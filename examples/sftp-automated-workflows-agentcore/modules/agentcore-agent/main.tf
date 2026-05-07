# ─────────────────────────────────────────────────────────────────────────────
# AgentCore Agent Runtime module
#
# Builds a Python agent package (source + pip dependencies) into a zip, uploads
# it to a shared S3 code bucket, and creates a Bedrock AgentCore runtime that
# loads and executes the code. Also provisions the runtime's IAM execution role
# and its inline permission policies.
#
# Resources are split across files by concern:
#   • main.tf       — terraform block, provider, account/region data sources
#   • build.tf      — local-exec build step that produces the agent zip
#   • s3.tf         — S3 object upload of the built zip
#   • agentcore.tf  — aws_bedrockagentcore_agent_runtime (the runtime itself)
#   • iam.tf        — execution role and inline policies
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.17"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
