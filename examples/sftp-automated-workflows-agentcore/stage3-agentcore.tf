################################################################################
# Stage 3: AI Claims Processing
# Components: Agentcore with Amazon Bedrock (Agent Deployment Only)
################################################################################

# Data sources to reference ECR repositories from Stage 0
data "aws_ecr_repository" "workflow_agent" {
  count = var.enable_agentcore ? 1 : 0
  name  = "claims-processing-demo-workflow-agent"
}

data "aws_ecr_repository" "entity_extraction_agent" {
  count = var.enable_agentcore ? 1 : 0
  name  = "claims-processing-demo-entity-extraction-agent"
}

data "aws_ecr_repository" "fraud_validation_agent" {
  count = var.enable_agentcore ? 1 : 0
  name  = "claims-processing-demo-fraud-validation-agent"
}

data "aws_ecr_repository" "database_insertion_agent" {
  count = var.enable_agentcore ? 1 : 0
  name  = "claims-processing-demo-database-insertion-agent"
}

data "aws_ecr_repository" "summary_generation_agent" {
  count = var.enable_agentcore ? 1 : 0
  name  = "claims-processing-demo-summary-generation-agent"
}

# Deploy AI-powered claims processing agents using Amazon Bedrock
module "agentcore" {
  count  = var.enable_agentcore ? 1 : 0
  source = "./modules/agentcore"

  aws_region  = var.aws_region
  bucket_name = var.enable_malware_protection ? module.s3_bucket_clean[0].s3_bucket_id : null

  # Pass ECR repository URLs from Stage 0
  workflow_agent_ecr_url            = data.aws_ecr_repository.workflow_agent[0].repository_url
  entity_extraction_agent_ecr_url   = data.aws_ecr_repository.entity_extraction_agent[0].repository_url
  fraud_validation_agent_ecr_url    = data.aws_ecr_repository.fraud_validation_agent[0].repository_url
  database_insertion_agent_ecr_url  = data.aws_ecr_repository.database_insertion_agent[0].repository_url
  summary_generation_agent_ecr_url  = data.aws_ecr_repository.summary_generation_agent[0].repository_url

  # Skip ECR and Docker builds in module
  skip_ecr_and_docker = true
}
