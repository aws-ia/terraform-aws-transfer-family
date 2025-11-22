################################################################################
# Stage 3: AI Claims Processing
# Components: Agentcore with Amazon Bedrock
################################################################################

# Deploy AI-powered claims processing agents using Amazon Bedrock
module "agentcore" {
  count  = var.enable_agentcore ? 1 : 0
  source = "./modules/agentcore"

  aws_region  = var.aws_region
  bucket_name = var.enable_malware_protection ? module.s3_bucket_clean[0].s3_bucket_id : null
}
