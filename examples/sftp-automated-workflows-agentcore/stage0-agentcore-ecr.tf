################################################################################
# Stage 0: AgentCore ECR Repositories and Docker Images
# Components: ECR repos and Docker image builds for all agents
################################################################################

# ECR Repositories
resource "aws_ecr_repository" "workflow_agent" {
  count        = var.enable_agentcore_ecr ? 1 : 0
  name         = "claims-processing-demo-workflow-agent"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project     = "claims-processing"
    Environment = "demo"
    Agent       = "workflow"
  }
}

resource "aws_ecr_repository" "entity_extraction_agent" {
  count        = var.enable_agentcore_ecr ? 1 : 0
  name         = "claims-processing-demo-entity-extraction-agent"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project     = "claims-processing"
    Environment = "demo"
    Agent       = "entity-extraction"
  }
}

resource "aws_ecr_repository" "fraud_validation_agent" {
  count        = var.enable_agentcore_ecr ? 1 : 0
  name         = "claims-processing-demo-fraud-validation-agent"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project     = "claims-processing"
    Environment = "demo"
    Agent       = "fraud-validation"
  }
}

resource "aws_ecr_repository" "database_insertion_agent" {
  count        = var.enable_agentcore_ecr ? 1 : 0
  name         = "claims-processing-demo-database-insertion-agent"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project     = "claims-processing"
    Environment = "demo"
    Agent       = "database-insertion"
  }
}

resource "aws_ecr_repository" "summary_generation_agent" {
  count        = var.enable_agentcore_ecr ? 1 : 0
  name         = "claims-processing-demo-summary-generation-agent"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project     = "claims-processing"
    Environment = "demo"
    Agent       = "summary-generation"
  }
}

# Docker Image Builds
resource "null_resource" "workflow_agent_image" {
  count = var.enable_agentcore_ecr ? 1 : 0

  triggers = {
    dockerfile_hash   = filesha256("${path.module}/modules/agentcore/docker/Dockerfile.workflow")
    agent_hash        = filesha256("${path.module}/modules/agentcore/agents/orchestrator/claims_workflow.py")
    requirements_hash = filesha256("${path.module}/modules/agentcore/requirements.txt")
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
      source ~/.bash_profile || source ~/.profile || true
      
      if ! command -v docker &> /dev/null; then
        echo "Docker is not installed or not in PATH. Please install Docker and try again."
        exit 1
      fi
      
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
      
      cd ${path.module}/modules/agentcore
      docker build --platform linux/arm64 -t ${aws_ecr_repository.workflow_agent[0].repository_url}:latest -f docker/Dockerfile.workflow .
      docker push ${aws_ecr_repository.workflow_agent[0].repository_url}:latest
    EOF
  }

  depends_on = [aws_ecr_repository.workflow_agent]
}

resource "null_resource" "entity_extraction_agent_image" {
  count = var.enable_agentcore_ecr ? 1 : 0

  triggers = {
    dockerfile_hash   = filesha256("${path.module}/modules/agentcore/docker/Dockerfile.entity")
    agent_hash        = filesha256("${path.module}/modules/agentcore/agents/individual_agents/entity_extraction_agent.py")
    requirements_hash = filesha256("${path.module}/modules/agentcore/requirements.txt")
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
      source ~/.bash_profile || source ~/.profile || true
      
      if ! command -v docker &> /dev/null; then
        echo "Docker is not installed or not in PATH. Please install Docker and try again."
        exit 1
      fi
      
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
      
      cd ${path.module}/modules/agentcore
      docker build --platform linux/arm64 -t ${aws_ecr_repository.entity_extraction_agent[0].repository_url}:latest -f docker/Dockerfile.entity .
      docker push ${aws_ecr_repository.entity_extraction_agent[0].repository_url}:latest
    EOF
  }

  depends_on = [aws_ecr_repository.entity_extraction_agent]
}

resource "null_resource" "fraud_validation_agent_image" {
  count = var.enable_agentcore_ecr ? 1 : 0

  triggers = {
    dockerfile_hash   = filesha256("${path.module}/modules/agentcore/docker/Dockerfile.fraud")
    agent_hash        = filesha256("${path.module}/modules/agentcore/agents/individual_agents/fraud_validation_agent.py")
    requirements_hash = filesha256("${path.module}/modules/agentcore/requirements.txt")
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
      source ~/.bash_profile || source ~/.profile || true
      
      if ! command -v docker &> /dev/null; then
        echo "Docker is not installed or not in PATH. Please install Docker and try again."
        exit 1
      fi
      
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
      
      cd ${path.module}/modules/agentcore
      docker build --platform linux/arm64 -t ${aws_ecr_repository.fraud_validation_agent[0].repository_url}:latest -f docker/Dockerfile.fraud .
      docker push ${aws_ecr_repository.fraud_validation_agent[0].repository_url}:latest
    EOF
  }

  depends_on = [aws_ecr_repository.fraud_validation_agent]
}

resource "null_resource" "database_insertion_agent_image" {
  count = var.enable_agentcore_ecr ? 1 : 0

  triggers = {
    dockerfile_hash   = filesha256("${path.module}/modules/agentcore/docker/Dockerfile.db")
    agent_hash        = filesha256("${path.module}/modules/agentcore/agents/individual_agents/database_insertion_agent.py")
    requirements_hash = filesha256("${path.module}/modules/agentcore/requirements.txt")
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
      source ~/.bash_profile || source ~/.profile || true
      
      if ! command -v docker &> /dev/null; then
        echo "Docker is not installed or not in PATH. Please install Docker and try again."
        exit 1
      fi
      
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
      
      cd ${path.module}/modules/agentcore
      docker build --platform linux/arm64 -t ${aws_ecr_repository.database_insertion_agent[0].repository_url}:latest -f docker/Dockerfile.db .
      docker push ${aws_ecr_repository.database_insertion_agent[0].repository_url}:latest
    EOF
  }

  depends_on = [aws_ecr_repository.database_insertion_agent]
}

resource "null_resource" "summary_generation_agent_image" {
  count = var.enable_agentcore_ecr ? 1 : 0

  triggers = {
    dockerfile_hash   = filesha256("${path.module}/modules/agentcore/docker/Dockerfile.summary")
    agent_hash        = filesha256("${path.module}/modules/agentcore/agents/individual_agents/summary_report_agent.py")
    requirements_hash = filesha256("${path.module}/modules/agentcore/requirements.txt")
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
      source ~/.bash_profile || source ~/.profile || true
      
      if ! command -v docker &> /dev/null; then
        echo "Docker is not installed or not in PATH. Please install Docker and try again."
        exit 1
      fi
      
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
      
      cd ${path.module}/modules/agentcore
      docker build --platform linux/arm64 -t ${aws_ecr_repository.summary_generation_agent[0].repository_url}:latest -f docker/Dockerfile.summary .
      docker push ${aws_ecr_repository.summary_generation_agent[0].repository_url}:latest
    EOF
  }

  depends_on = [aws_ecr_repository.summary_generation_agent]
}
