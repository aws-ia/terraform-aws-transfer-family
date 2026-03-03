## NOTE: This is the minimum mandatory test
# run at least one test using the ./examples directory as your module source
# create additional *.tftest.hcl for your own unit / integration tests
# use tests/*.auto.tfvars to add non-default variables
run "mandatory_plan_basic" {
  command = plan
  module {
    source = "./examples/sftp-public-endpoint-service-managed-S3"
  }
}

run "mandatory_apply_basic" {
  command = apply
  module {
    source = "./examples/sftp-public-endpoint-service-managed-S3"
  }
}

run "mandatory_plan_vpc" {
  command = plan
  module {
    source = "./examples/sftp-internet-facing-vpc-endpoint-service-managed-S3"
  }
  variables {
    sftp_ingress_cidr_block = "10.0.0.0/16, 192.168.1.0/24, 172.16.0.0/12"
  }
}

run "mandatory_apply_vpc" {
  command = apply
  module {
    source = "./examples/sftp-internet-facing-vpc-endpoint-service-managed-S3"
  }
  variables {
    sftp_ingress_cidr_block = "10.0.0.0/16, 192.168.1.0/24, 172.16.0.0/12"
  }
}

run "connector_file_send_plan" {
  command = plan
  module {
    source = "./examples/sftp-connector-automated-file-send"
  }
  variables {
    sftp_server_endpoint = run.mandatory_apply_basic.server_endpoint
    existing_secret_arn = run.mandatory_apply_basic.test_user_secret.private_key_secret.arn
  }
}

run "connector_file_send_apply" {
  command = apply
  module {
    source = "./examples/sftp-connector-automated-file-send"
  }
  variables {
    sftp_server_endpoint = run.mandatory_apply_basic.server_endpoint
    existing_secret_arn = run.mandatory_apply_basic.test_user_secret.private_key_secret.arn
  }
}

run "connector_retrieve_static_plan" {
  command = plan
  module {
    source = "./examples/sftp-connector-automated-file-retrieve-static"
  }
  variables {
    sftp_server_endpoint = run.mandatory_apply_basic.server_endpoint
    existing_secret_arn = run.mandatory_apply_basic.test_user_secret.private_key_secret.arn
    enable_dynamodb_tracking = false
  }
}

run "connector_retrieve_static_apply" {
  command = apply
  module {
    source = "./examples/sftp-connector-automated-file-retrieve-static"
  }
  variables {
    sftp_server_endpoint = run.mandatory_apply_basic.server_endpoint
    existing_secret_arn = run.mandatory_apply_basic.test_user_secret.private_key_secret.arn
    enable_dynamodb_tracking = false
  }
}

run "connector_retrieve_dynamic_plan" {
  command = plan
  module {
    source = "./examples/sftp-connector-automated-file-retrieve-dynamic"
  }
  variables {
    sftp_server_endpoint = run.mandatory_apply_basic.server_endpoint
    existing_secret_arn = run.mandatory_apply_basic.test_user_secret.private_key_secret.arn
  }
}

run "connector_retrieve_dynamic_apply" {
  command = apply
  module {
    source = "./examples/sftp-connector-automated-file-retrieve-dynamic"
  }
  variables {
    sftp_server_endpoint = run.mandatory_apply_basic.server_endpoint
    existing_secret_arn = run.mandatory_apply_basic.test_user_secret.private_key_secret.arn
  }
}

run "malware_protection_plan" {
  command = plan
  module {
    source = "./examples/sftp-malware-protection-guardduty"
  }
}

run "malware_protection_apply" {
  command = apply
  module {
    source = "./examples/sftp-malware-protection-guardduty"
  }
}

run "web_app_plan" {
  command = plan
  module {
    source = "./examples/sample-web-app"
  }
  variables {
    create_identity_center_instance = true
    create_test_users_and_groups = true
    logo_file = "./examples/sample-web-app/anycompany-logo-small.png"
    favicon_file = "./examples/sample-web-app/favicon.png"
  }
}

run "web_app_apply" {
  command = apply
  module {
    source = "./examples/sample-web-app"
  }
  variables {
    create_identity_center_instance = true
    create_test_users_and_groups = true
    logo_file = "./examples/sample-web-app/anycompany-logo-small.png"
    favicon_file = "./examples/sample-web-app/favicon.png"
  }
}

run "entra_id_example_plan" {
  command = plan
  module {
    source = "./examples/sftp-idp-entra-lambda"
  }
  variables {
    entra_usernames   = ["user@example.onmicrosoft.com"]
    entra_provider_name = "example.onmicrosoft.com"
    entra_client_id = "a11aaaa1-1111-1a11-111a-11a11a1a11aa"
    entra_authority_url = "https://login.microsoftonline.com/xyz"
    entra_client_secret_name = "entra_client_secret"
    provision_api   = false
  }
}

run "entra_id_example_apply" {
  command = apply
  module {
    source = "./examples/sftp-idp-entra-lambda"
  }
  variables {
    entra_usernames   = ["user@example.onmicrosoft.com"]
    entra_provider_name = "example.onmicrosoft.com"
    entra_client_id = "a11aaaa1-1111-1a11-111a-11a11a1a11aa"
    entra_authority_url = "https://login.microsoftonline.com/xyz"
    entra_client_secret_name = "entra_client_secret"
    provision_api   = false
  }
}