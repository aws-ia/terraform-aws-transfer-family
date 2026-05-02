resource "aws_s3_object" "agent_code" {
  bucket      = var.code_bucket_id
  key         = local.s3_prefix
  source      = local.zip_path
  source_hash = local.source_content_hash

  depends_on = [terraform_data.build_agent_package]
}