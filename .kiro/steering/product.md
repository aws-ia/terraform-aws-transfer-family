# AWS Transfer Family Terraform Module

This is a Terraform module for creating and managing AWS Transfer Family servers, specifically focused on SFTP file transfer capabilities. The module provides a complete solution for deploying secure file transfer infrastructure on AWS.

## Key Features

- **SFTP Server Deployment**: Creates AWS Transfer Family servers with SFTP protocol support
- **Flexible Endpoint Types**: Supports both PUBLIC and VPC endpoint configurations
- **Custom DNS Integration**: Optional Route53 integration and custom hostname support
- **Security & Compliance**: Built-in security policies and CloudWatch logging
- **Modular Architecture**: Separate modules for server, users, and custom identity providers

## Primary Use Cases

- Secure file transfer for enterprise applications
- B2B data exchange with external partners
- Migration from legacy FTP/SFTP infrastructure to AWS
- Compliance-focused file transfer with audit logging

The module is maintained by AWS Solution Architects and follows AWS best practices for infrastructure as code.