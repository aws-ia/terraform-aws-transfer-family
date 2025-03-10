# resource "aws_iam_role" "logging" {
#   count = var.enable_logging ? 1 : 0

#   name = "${var.server_name}-logging-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "transfer.amazonaws.com"
#         }
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy" "logging" {
#   count = var.enable_logging ? 1 : 0

#   name = "${var.server_name}-logging-policy"
#   role = aws_iam_role.logging[0].id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "logs:CreateLogStream",
#           "logs:DescribeLogStreams",
#           "logs:CreateLogGroup",
#           "logs:PutLogEvents"
#         ]
#         Resource = "arn:aws:logs:*:*:*"
#       }
#     ]
#   })
# }