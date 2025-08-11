# SFTP Server with Multiple SSH Keys Example

This example demonstrates how to create an AWS Transfer Family SFTP server with users that have multiple SSH public keys. This configuration showcases:

- **Single Key User**: Traditional single SSH key configuration for backward compatibility
- **Multiple Key User**: User with multiple SSH keys for key rotation and redundancy
- **Key Rotation User**: User with both current and new keys for seamless rotation

## Key Features

- Support for both single and multiple SSH keys per user
- Demonstrates key rotation scenarios
- Shows mixed user configurations in the same deployment
- Uses service-managed identity provider
- Includes S3 bucket with KMS encryption
- CloudWatch logging enabled

## Usage

Replace the example SSH keys in the `users` local variable with your actual public keys before deploying.

**Note**: The SSH keys in this example are truncated for readability. You must provide complete, valid SSH public keys.

## User Configuration Examples

### Single Key User (Backward Compatibility)
```hcl
{
  username = "single-key-user"
  home_dir = "/single-key-user"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7... single-key-example"
}
```

### Multiple Key User
```hcl
{
  username = "multi-key-user"
  home_dir = "/multi-key-user"
  public_keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7... primary-key",
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... backup-key",
    "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTY... rotation-key"
  ]
}
```

### Key Rotation Scenario
```hcl
{
  username = "rotation-user"
  home_dir = "/rotation-user"
  public_keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7... current-key",
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQD8... new-key-for-rotation"
  ]
}
```

## Key Management Best Practices

1. **Key Rotation**: Add new keys before removing old ones to ensure continuous access
2. **Key Limits**: AWS Transfer Family supports up to 10 SSH keys per user
3. **Key Formats**: Supported formats include ssh-rsa, ssh-ed25519, and ecdsa-sha2-nistp256/384/521
4. **Validation**: All keys are validated for proper format and uniqueness

## Security Considerations

- All S3 bucket public access is blocked
- KMS encryption is enabled for Amazon S3
- CloudWatch logging is enabled
- IAM roles follow least privilege principles

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.95.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.95.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_s3_bucket"></a> [s3\_bucket](#module\_s3\_bucket) | git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git | v5.0.0 |
| <a name="module_sftp_users"></a> [sftp\_users](#module\_sftp\_users) | ../../modules/transfer-users | n/a |
| <a name="module_transfer_server"></a> [transfer\_server](#module\_transfer\_server) | ../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_kms_alias.transfer_family_key_alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.transfer_family_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_key_policy.transfer_family_key_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key_policy) | resource |
| [random_pet.name](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"us-east-1"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_s3_bucket_name"></a> [s3\_bucket\_name](#output\_s3\_bucket\_name) | Name of the S3 bucket used for file storage | 
| <a name="output_server_endpoint"></a> [server\_endpoint](#output\_server\_endpoint) | Endpoint of the Transfer Family server |
| <a name="output_server_id"></a> [server\_id](#output\_server\_id) | ID of the Transfer Family server |
| <a name="output_user_details"></a> [user\_details](#output\_user\_details) | Details of created users including their public keys |