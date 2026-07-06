# Cognito Hosted UI Complete Example

This example demonstrates how to use the cognito-hosted-ui module with all features enabled.

## Features Demonstrated

- Cognito User Pool with Managed Login (Hosted UI v2)
- CloudFront-backed landing page with OAuth callback handling
- Custom branding with example `cognito-branding.json`
- Generic landing page template with token exchange
- Test user creation with password stored in Secrets Manager
- Configurable password policies

## Included Files

- `landing.html` - Generic landing page template with authentication flow
- `cognito-branding.json` - Example Cognito Managed Login branding configuration

## Usage

1. Copy the example configuration:

```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Update `terraform.tfvars` with your configuration:
   - Set a globally unique `domain_prefix` (REQUIRED - must be unique across all AWS accounts)
   - The example uses the included `landing.html` and `cognito-branding.json`
   - Optionally customize these files for your needs
   - Configure test user settings if needed

3. Initialize and apply:

```bash
terraform init
terraform plan
terraform apply
```

3. Access the landing page:

```bash
terraform output cloudfront_url
```

4. If you created a test user, retrieve the password:

```bash
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw test_user_password_secret_arn) \
  --query SecretString \
  --output text | jq -r .password
```

## Testing the Authentication Flow

1. Navigate to the CloudFront URL from the outputs
2. Click the login button to be redirected to Cognito Managed Login
3. Sign in with the test user credentials
4. After successful authentication, you'll be redirected back to the landing page with tokens

## Cleanup

```bash
terraform destroy
```

## Notes

- The `domain_prefix` must be globally unique across all AWS accounts
- Changes to branding settings or landing page template will trigger updates
- The test user password is randomly generated and stored in Secrets Manager
- CloudFront distributions can take 15-20 minutes to fully deploy
