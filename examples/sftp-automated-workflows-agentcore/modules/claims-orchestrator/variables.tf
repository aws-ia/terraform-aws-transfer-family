variable "name_prefix" {
  description = "Resource naming prefix"
  type        = string
}

variable "source_dir" {
  description = "Path to the orchestrator Python source code directory"
  type        = string
}

variable "claims_bucket_name" {
  description = "S3 bucket name for claims data"
  type        = string
}

variable "claims_bucket_arn" {
  description = "S3 bucket ARN for claims data"
  type        = string
}

variable "claims_table_name" {
  description = "Name of the claims DynamoDB table"
  type        = string
}

variable "claims_table_arn" {
  description = "ARN of the claims DynamoDB table"
  type        = string
}

variable "document_extraction_agent_arn" {
  description = "ARN of the Document Extraction AgentCore Runtime"
  type        = string
}

variable "damage_assessment_agent_arn" {
  description = "ARN of the Damage Assessment AgentCore Runtime"
  type        = string
}

variable "fraud_detection_agent_arn" {
  description = "ARN of the Fraud Detection AgentCore Runtime"
  type        = string
}

variable "classification_agent_arn" {
  description = "ARN of the Classification AgentCore Runtime"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
