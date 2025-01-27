output "server_id" {
  description = "The ID of the SFTP server"
  value       = aws_transfer_server.sftp.id
}