output "user_assignments" {
  description = "Map of username to user assignment details"
  value = {
    for username, assignment in aws_ssoadmin_application_assignment.users : username => {
      application_arn = assignment.application_arn
      principal_id    = assignment.principal_id
      principal_type  = assignment.principal_type
    }
  }
}

output "group_assignments" {
  description = "Map of group name to group assignment details"
  value = {
    for group_name, assignment in aws_ssoadmin_application_assignment.groups : group_name => {
      application_arn = assignment.application_arn
      principal_id    = assignment.principal_id
      principal_type  = assignment.principal_type
    }
  }
}

output "user_access_grants" {
  description = "Map of user access grants"
  value = {
    for key, grant in aws_s3control_access_grant.user_grants : key => {
      grant_id   = grant.access_grant_id
      grant_arn  = grant.access_grant_arn
      permission = grant.permission
    }
  }
}

output "group_access_grants" {
  description = "Map of group access grants"
  value = {
    for key, grant in aws_s3control_access_grant.group_grants : key => {
      grant_id   = grant.access_grant_id
      grant_arn  = grant.access_grant_arn
      permission = grant.permission
    }
  }
}
