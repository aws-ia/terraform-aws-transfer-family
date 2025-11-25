# Workflow Agent Runtime
module "workflow_agent" {
  source = "aws-ia/agentcore/aws"

  gateway_exception_level = "PARTIAL"
  depends_on              = [null_resource.workflow_agent_image]

  create_runtime        = true
  runtime_name          = "workflow_agent"
  runtime_description   = "Claims processing workflow orchestrator"
  runtime_container_uri = "${local.workflow_agent_url}:latest"
  runtime_network_mode  = "PUBLIC"

  runtime_environment_variables = {
    "LOG_LEVEL"          = var.log_level
    "ENV"                = var.environment
    "AWS_REGION"         = var.aws_region
    "ENTITY_AGENT_ARN"   = module.entity_extraction_agent.agent_runtime_arn
    "FRAUD_AGENT_ARN"    = module.fraud_validation_agent.agent_runtime_arn
    "DATABASE_AGENT_ARN" = module.database_insertion_agent.agent_runtime_arn
    "SUMMARY_AGENT_ARN"  = module.summary_generation_agent.agent_runtime_arn
  }

  runtime_tags = {
    Environment = var.environment
    Project     = var.project_name
    Agent       = "workflow"
  }

  create_runtime_endpoint      = true
  runtime_endpoint_name        = "workflow_agent_endpoint"
  runtime_endpoint_description = "Workflow agent endpoint"

  runtime_endpoint_tags = {
    Environment = var.environment
    Project     = var.project_name
    Agent       = "workflow"
  }
}

# Entity Extraction Agent Runtime
module "entity_extraction_agent" {
  source = "aws-ia/agentcore/aws"

  gateway_exception_level = "PARTIAL"
  depends_on              = [null_resource.entity_extraction_agent_image]

  create_runtime        = true
  runtime_name          = "entity_extraction_agent"
  runtime_description   = "Extracts entities from PDF documents"
  runtime_container_uri = "${local.entity_extraction_agent_url}:latest"
  runtime_network_mode  = "PUBLIC"

  runtime_environment_variables = {
    "LOG_LEVEL"  = var.log_level
    "ENV"        = var.environment
    "AWS_REGION" = var.aws_region
  }

  create_runtime_endpoint      = true
  runtime_endpoint_name        = "entity_extraction_agent_endpoint"
  runtime_endpoint_description = "Entity extraction agent endpoint"

  runtime_endpoint_tags = {
    Environment = var.environment
    Project     = var.project_name
    Agent       = "entity-extraction"
  }
}

# Fraud Validation Agent Runtime
module "fraud_validation_agent" {
  source = "aws-ia/agentcore/aws"

  gateway_exception_level = "PARTIAL"
  depends_on              = [null_resource.fraud_validation_agent_image]

  create_runtime        = true
  runtime_name          = "validation_agent"
  runtime_description   = "Validates claims for fraud detection"
  runtime_container_uri = "${local.fraud_validation_agent_url}:latest"
  runtime_network_mode  = "PUBLIC"

  runtime_environment_variables = {
    "LOG_LEVEL"  = var.log_level
    "ENV"        = var.environment
    "AWS_REGION" = var.aws_region
  }

  runtime_tags = {
    Environment = var.environment
    Project     = var.project_name
    Agent       = "fraud-validation"
  }

  create_runtime_endpoint      = true
  runtime_endpoint_name        = "validation_agent_endpoint"
  runtime_endpoint_description = "Fraud validation agent endpoint"

  runtime_endpoint_tags = {
    Environment = var.environment
    Project     = var.project_name
    Agent       = "fraud-validation"
  }
}

# Database Insertion Agent Runtime
module "database_insertion_agent" {
  source = "aws-ia/agentcore/aws"

  gateway_exception_level = "PARTIAL"
  depends_on              = [null_resource.database_insertion_agent_image]

  create_runtime        = true
  runtime_name          = "database_insertion_agent"
  runtime_description   = "Inserts processed claims into DynamoDB"
  runtime_container_uri = "${local.database_insertion_agent_url}:latest"
  runtime_network_mode  = "PUBLIC"

  runtime_environment_variables = {
    "LOG_LEVEL"  = var.log_level
    "ENV"        = var.environment
    "AWS_REGION" = var.aws_region
  }

  runtime_tags = {
    Environment = var.environment
    Project     = var.project_name
    Agent       = "database-insertion"
  }

  create_runtime_endpoint      = true
  runtime_endpoint_name        = "database_insertion_agent_endpoint"
  runtime_endpoint_description = "Database insertion agent endpoint"

  runtime_endpoint_tags = {
    Environment = var.environment
    Project     = var.project_name
    Agent       = "database-insertion"
  }
}

# Summary Generation Agent Runtime
module "summary_generation_agent" {
  source = "aws-ia/agentcore/aws"

  gateway_exception_level = "PARTIAL"
  depends_on              = [null_resource.summary_generation_agent_image]

  create_runtime        = true
  runtime_name          = "summary_generation_agent"
  runtime_description   = "Generates summary reports for processed claims"
  runtime_container_uri = "${local.summary_generation_agent_url}:latest"
  runtime_network_mode  = "PUBLIC"

  runtime_environment_variables = {
    "LOG_LEVEL"  = var.log_level
    "ENV"        = var.environment
    "AWS_REGION" = var.aws_region
  }

  runtime_tags = {
    Environment = var.environment
    Project     = var.project_name
    Agent       = "summary-generation"
  }

  create_runtime_endpoint      = true
  runtime_endpoint_name        = "summary_generation_agent_endpoint"
  runtime_endpoint_description = "Summary generation agent endpoint"

  runtime_endpoint_tags = {
    Environment = var.environment
    Project     = var.project_name
    Agent       = "summary-generation"
  }
}
