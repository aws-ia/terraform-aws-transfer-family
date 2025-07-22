output "server_id" {
  description = "The ID of the transfer server"
  value       = aws_transfer_server.transfer_server.id
}

output "server_endpoint" {
  description = "The endpoint of the created Transfer Family server"
  value       = aws_transfer_server.transfer_server.endpoint
}