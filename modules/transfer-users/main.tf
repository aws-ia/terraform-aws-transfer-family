module "sftp_keys" {
  source = "../sftp-keys"
  users  = var.users
}

# Create SFTP users
resource "aws_transfer_user" "transfer_users" {
  for_each = { for user in var.users : user.username => user }

  server_id = var.server_id
  user_name = each.value.username
  role      = aws_iam_role.sftp_user_roles[each.key].arn

  home_directory_type = "LOGICAL"
  home_directory_mappings {
    entry  = "/"
    target = "/${var.s3_bucket_name}${each.value.home_dir}"
  }
}

# Create SSH keys for users
resource "aws_transfer_ssh_key" "user_ssh_keys" {
  for_each = { for user in var.users : user.username => user }

  server_id = var.server_id
  user_name = each.value.username
  body      = module.sftp_keys.public_keys[each.key]

  depends_on = [aws_transfer_user.transfer_users]
}