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
