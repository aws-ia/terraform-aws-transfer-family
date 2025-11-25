variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-2"
}

variable "skip_ecr_and_docker" {
  description = "Skip ECR repository creation and Docker builds (use existing repos)"
  type        = bool
  default     = false
}

variable "workflow_agent_ecr_url" {
  description = "ECR repository URL for workflow agent"
  type        = string
  default     = ""
}

variable "entity_extraction_agent_ecr_url" {
  description = "ECR repository URL for entity extraction agent"
  type        = string
  default     = ""
}

variable "fraud_validation_agent_ecr_url" {
  description = "ECR repository URL for fraud validation agent"
  type        = string
  default     = ""
}

variable "database_insertion_agent_ecr_url" {
  description = "ECR repository URL for database insertion agent"
  type        = string
  default     = ""
}

variable "summary_generation_agent_ecr_url" {
  description = "ECR repository URL for summary generation agent"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "claims-processing"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "demo"
}

variable "log_level" {
  description = "Log level for agents"
  type        = string
  default     = "INFO"
}

variable "bucket_name" {
  description = "S3 bucket name for claims"
  type        = string
}
