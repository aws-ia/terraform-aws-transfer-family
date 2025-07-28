provider "aws" {
  region = var.aws_region

  # Enable if you need to specify a specific profile
  # profile = "default"

  default_tags {
    tags = {
      Environment = var.stage
      ManagedBy   = "terraform"
    }
  }
}

# Configure the AWS Provider for us-east-1 (required for some global resources)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = var.stage
      ManagedBy   = "terraform"
    }
  }
}
