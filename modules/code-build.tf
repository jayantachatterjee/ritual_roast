# --- 1. Dynamic ECR Repository ---
resource "aws_ecr_repository" "ecs_test_my_app_repo" {
  name                 = "ecs_testmy-dynamic-app-repo"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# --- 2. IAM Role for CodeBuild ---
resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-docker-build-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      },
    ]
  })
}


# --- 3. IAM Policy (Permissions to talk to ECR & CloudWatch) ---
resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Resource = [
          "*" # For logs/report groups
        ]
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:GetAuthorizationToken",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        # Restrict permissions strictly to the repo created above
        Resource = aws_ecr_repository.ecs_test_my_app_repo.arn 
      },
      {
        Effect = "Allow"
        Action = "ecr:GetAuthorizationToken"
        Resource = "*"
      }
    ]
  })
}

# --- 4. CodeBuild Project ---
resource "aws_codebuild_project" "ecs_test_docker_builder" {
  name          = "ecs_test_my-docker-build-project"
  description   = "Builds Docker image and pushes to ECR"
  build_timeout = "5"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  # Define the Docker environment
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    
    # REQUIRED for building Docker images inside CodeBuild
    privileged_mode = true 

    # === THE CRITICAL PART ===
    # We inject the dynamic ECR URL here
    environment_variable {
      name  = "ECR_REPOSITORY_URI"
      value = aws_ecr_repository.ecs_test_my_app_repo.repository_url
    }
    
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = "ap-southeast-1" # Or utilize data.aws_region.current.name
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/jayantachatterjee/ritual_roast.git"
    git_clone_depth = 1
    buildspec = "buildspec.yml"
    # By default, it looks for 'buildspec.yml' in the root.
    # If it is elsewhere, specify: buildspec = "path/to/buildspec.yml"
  }
}

# --- 5. Trigger CodeBuild on CodeCommit Push (Optional) ---
resource "aws_codebuild_webhook" "ecs_test_codebuild_webhook" {
  project_name = aws_codebuild_project.ecs_test_docker_builder.name

   # This filter ensures the build only triggers on Pushes to the Main branch
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }

    filter {
      type    = "HEAD_REF"
      # Regex for the branch name. Use "^refs/heads/master$" if you still use master
      pattern = "^refs/heads/main$" 
    }
  }
}


# --- 1. ECR API Endpoint (For Authentication) ---
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.ecs_test_vpc.id
  service_name        = "com.amazonaws.ap-southeast-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.ecs_test_private_app_subnet[*].id
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.ecs_test_vpc_endpoint_sg.id]
}

# --- 2. ECR Docker Endpoint (For Image Pulls) ---
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.ecs_test_vpc.id
  service_name        = "com.amazonaws.ap-southeast-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.ecs_test_private_app_subnet[*].id
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.ecs_test_vpc_endpoint_sg.id]
}

# --- 3. S3 Gateway Endpoint (REQUIRED for Image Layers) ---
# ECR stores the actual image layers in S3. 
# Without this, the auth works but the download hangs/fails.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.ecs_test_vpc.id
  service_name      = "com.amazonaws.ap-southeast-1.s3"
  vpc_endpoint_type = "Gateway"
  
  # Gateway endpoints are attached to Route Tables, not Subnets!
  route_table_ids   = aws_route_table.ecs_test_private[*].id
}