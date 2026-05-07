# Upload the built agent zip to the shared code bucket. The object is
# re-uploaded whenever source_content_hash changes (via source_hash), which
# propagates to the runtime through SOURCE_CONTENT_HASH in agentcore.tf.
resource "aws_s3_object" "agent_code" {
  bucket      = var.code_bucket_id
  key         = local.s3_prefix
  source      = local.zip_path
  source_hash = local.source_content_hash

  depends_on = [terraform_data.build_agent_package]
}