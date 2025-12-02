resource "aws_ecs_service" "ecs_test_service" {
  name            = "my-app-service"
  cluster         = aws_ecs_cluster.ecs_test_cluster.id
  task_definition = aws_ecs_task_definition.ecs_test_task_definition.arn
  launch_type     = "FARGATE"
  
  # Allow Auto Scaling to manage the count, preventing Terraform from resetting it
  lifecycle {
    ignore_changes = [desired_count] 
  }

  # Link to the ALB Target Group created above
  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_test_target_group.arn
    container_name   = "ecs-test-my-app-container" # Must match name in Task Definition
    container_port   = 80               # Must match port in Task Definition
  }

  network_configuration {
    subnets          = aws_subnet.ecs_test_private_app_subnet[*].id
    security_groups  = [aws_security_group.ecs_test_app_sg.id]
    assign_public_ip = false
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution_policy,
    aws_iam_role_policy.ecs_task_custom_policy
  ]
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/my-app-logs"
  retention_in_days = 7
}

# --- IAM Role: ECS Task Execution Role ---
# REQUIRED: This allows Fargate to pull images from ECR and write logs
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach the AWS-managed policy that gives ECR Pull & CloudWatch Write permissions
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- Custom IAM Policy for CloudWatch Logs ---
resource "aws_iam_role_policy" "ecs_task_custom_policy" {
  name   = "ecs-task-custom-policy"
  role   = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.ecs_log_group.arn}:*"
      }
    ]
  })
}

# --- 1. Create the IAM Role ---
# This allows the ECS service (Fargate) to assume this role.
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs-task-execution-newrole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# --- 2. Policy A: Connect to ECR & CloudWatch (AWS Managed) ---
# AWS provides a pre-made policy for ECR Pulls and Logging.
# We just need to attach it.
resource "aws_iam_role_policy_attachment" "ecs_execution_policy_attachment" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- 3. Policy B: Access Secrets Manager (Customer Managed) ---
# You need a custom policy to specifically allow reading your secrets.
resource "aws_iam_policy" "secrets_access_policy" {
  name        = "ecs-secrets-access-policy"
  description = "Allow ECS to read secrets from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "kms:Decrypt" # Required if your secret uses a custom KMS key
        ]
        # Best Practice: Restrict to specific secrets to reduce blast radius
        Resource = [
          aws_secretsmanager_secret.ecs_test_rds_credentials.arn
          # Add other secret ARNs here if needed
        ]
      }
    ]
  })
}

# --- 4. Attach Policy B to the Role ---
resource "aws_iam_role_policy_attachment" "ecs_secrets_attachment" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.secrets_access_policy.arn
}

# --- ECS Task Definition ---
resource "aws_ecs_task_definition" "ecs_test_task_definition" {
  family                   = "my-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "ecs-test-my-app-container"
      image     = "${aws_ecr_repository.ecs_test_my_app_repo.repository_url}:latest"
      essential = true
      
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_log_group.name
          "awslogs-region"        = "ap-southeast-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      environment = [
        { name = "DB_DATABASE", value = "ritualroast" },
        { name = "DB_SERVER", value = aws_db_instance.ecs_test_db_instance.address },
        { name = "SECRET_NAME", value = aws_secretsmanager_secret.ecs_test_rds_credentials.name },
        { name = "AWS_REGION", value = "ap-southeast-1" },
      ]
    }
  ])
}