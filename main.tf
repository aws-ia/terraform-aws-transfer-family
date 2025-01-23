# S3 bucket creation
resource "aws_s3_bucket" "sftp_bucket" {
  bucket = var.bucket_name
}

# Transfer Server creation
resource "aws_transfer_server" "sftp" {
  identity_provider_type    = "SERVICE_MANAGED"
/*identity_provider_type    = "AWS_DIRECTORY_SERVICE"
  endpoint_type             = "VPC"  # Required for Directory Service
  directory_id              = "d-xxxx"  # Your Directory Service ID*/

/*identity_provider_type    = "AWS_LAMBDA"
  function_name             = "my-lambda-function"  # Your Lambda function name*/

/*identity_provider_type    = "API_GATEWAY"
  url                       = "https://api-gateway-url"  # Your API Gateway URL
  invocation_role           = aws_iam_role.api_gateway_role.arn*/

  domain                    = "S3" # Or "EFS" if you want to use EFS for storage
  protocols                 = ["SFTP"]
  endpoint_type             = "PUBLIC"  # Or "VPC" if you want to use VPC endpoint

#   hostname = "sftp.yourdomain.com"  # Your custom hostname

  tags = {
    Name = "sftp-server"
    Environment = var.environment
  }
}