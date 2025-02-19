variable "users" {
  description = "List of SFTP users"
  type = list(object({
    username = string
    home_dir = string
  }))
}