################################################################################
# AWS Transfer Family — SFTP Automated Workflows with AgentCore
#
# An end-to-end P&C claims intake pipeline: SFTP server with custom IDP,
# GuardDuty malware scanning, 4 Bedrock AgentCore agents, an MCP gateway,
# an orchestrator Lambda, and a Transfer Family web app for adjuster/SIU
# review.
#
# Components are split across descriptive layer files in this directory:
#   - foundation.tf          Identity Center, S3 Access Grants, Cognito,
#                            Custom IDP
#   - agentcore-agents.tf    4 AgentCore agent runtimes
#   - transfer-server.tf     Transfer Family SFTP server + upload bucket
#   - malware-protection.tf  GuardDuty Malware Protection + bucket routing
#   - ai-orchestration.tf    DynamoDB + MCP gateway + claims orchestrator
#   - webapp.tf              Transfer Family Web App + S3 Access Grants
#
# A fresh `terraform apply` from this directory deploys every layer end-to-end
# (all enable_* flags default to true). For a stage-by-stage walkthrough, see
# walkthrough/README.md.
################################################################################
