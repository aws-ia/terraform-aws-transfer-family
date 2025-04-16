package test

import (
	"testing"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestTerraformBasicExample(t *testing.T) {
	t.Log("Starting Terraform test")

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		// Set the path to the Terraform code
		TerraformDir: "../examples/public-service-managed-endpoint-S3",

		//NOTE
		// * We do not need this since we are not using TFVARS file and passing everything as local variables
		
		// Variables to pass to the Terraform code using -var options
		Vars: map[string]interface{}{
			"environment": "dev",
			"server_name": "my-sftp-server",
			"enable_logging": true,
			"create_new_bucket": true,
			"s3_bucket_name": "my-sftp-storage-bucket",
			"users": []map[string]interface{}{
				{
					"username":       "user1",
					"home_directory": "user1",
				},
				{
					"username":       "user2",
					"home_directory": "user2",
				},
			},
			"secrets_prefix": "dev/sftp",
			"tags": map[string]string{
				"Environment": "dev",
				"Project":     "sftp-demo",
				"Terraform":   "true",
			}, 
		}, 
	})

	// Make sure to clean up resources after the test is done
	defer terraform.Destroy(t, terraformOptions)

	// Act: Initialize and apply Terraform code
	terraform.InitAndApply(t, terraformOptions)

	// Assert: Check if the outputs match what we expect
	serverId := terraform.Output(t, terraformOptions, "server_id")
	serverEndpoint := terraform.Output(t, terraformOptions, "server_endpoint")
	bucketName := terraform.Output(t, terraformOptions, "sftp_bucket_name")
	bucketArn := terraform.Output(t, terraformOptions, "sftp_bucket_arn")
	userDetails := terraform.Output(t, terraformOptions, "user_details")

	// Simple assertions to check if outputs exist and are not empty
	assert.NotEmpty(t, serverId, "server_id should not be empty")
	assert.NotEmpty(t, serverEndpoint, "server_endpoint should not be empty")
	assert.NotEmpty(t, bucketName, "sftp_bucket_name should not be empty")
	assert.NotEmpty(t, bucketArn, "sftp_bucket_arn should not be empty")
	assert.NotEmpty(t, userDetails, "user_details should not be empty")
}