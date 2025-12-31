# Group Configuration
# NOTE: - Groups must already exist in IAM Identity Center before adding them here
#       - access_grants can be given through individual users instead of groups
# Uncomment and customize the groups below as needed

locals {
  imported_groups = {
    # Uncomment and modify the examples below to add groups:

    # "admins" = {
    #   group_name = "Admins"
    #   access_grants = [
    #     {
    #       s3_path    = "/*"
    #       permission = "READWRITE" 
    #     }
    #   ]
    # },

    # "analysts" = {
    #   group_name = "Analysts"
    #   access_grants = [
    #     {
    #       s3_path    = "/*"
    #       permission = "READ"
    #     }
    #   ]
    # },

    # "developers" = {
    #   group_name = "Developers"
    #   access_grants = [
    #     {
    #       s3_path    = "/dev/*"
    #       permission = "READWRITE"
    #     }
    #   ]
    # }

  }
}
