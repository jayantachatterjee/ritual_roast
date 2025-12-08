variable "ingress_port_for_app" {
    description = "list of port will be open from LB SG"
    type        = list(number)
    default     = [80, 443]   
}

variable "ingress_port_for_db" {
    description = "list of port will be open for SSH"
    type        = list(number)
    default     = [3306]   
}

resource "aws_security_group" "ecs_test_lb_sg" {
    name        = "ecs-test-lb-sg"
    description = "Security group for ECS app servers"
    vpc_id      = aws_vpc.ecs_test_vpc.id
    
    ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from anywhere"
  }

    ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS from anywhere"
  }
}

resource "aws_security_group" "ecs_test_app_sg" {
    name        = "ecs-test-app-sg"
    description = "Security group for ECS app servers"
    vpc_id      = aws_vpc.ecs_test_vpc.id

    dynamic "ingress" {
        for_each = var.ingress_port_for_app
        content {
            from_port   = ingress.value
            to_port     = ingress.value
            protocol    = "tcp"
            security_groups = [aws_security_group.ecs_test_lb_sg.id]
        }
    }

    # CRITICAL: Allow outbound HTTPS to VPC endpoints (ECR API, ECR Docker, S3)
    egress {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "Allow HTTPS to VPC endpoints (ECR, S3)"
    }

    # Allow outbound DNS for resolving VPC endpoint DNS names
    egress {
        from_port   = 53
        to_port     = 53
        protocol    = "udp"
        cidr_blocks = ["10.0.0.0/16"]
        description = "Allow DNS queries"
    }

    # Allow outbound to RDS if needed
    egress {
        from_port   = 3306
        to_port     = 3306
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/16"]
        description = "Allow MySQL to RDS"
    }
}

resource "aws_security_group" "ecs_test_db_sg" {
    name        = "ecs-test-db-sg"
    description = "Security group for RDS database"
    vpc_id      = aws_vpc.ecs_test_vpc.id

    dynamic "ingress" {
        for_each = var.ingress_port_for_db
        content {
            from_port   = ingress.value
            to_port     = ingress.value
            protocol    = "tcp"
            security_groups = [aws_security_group.ecs_test_app_sg.id]
        }
    }
}

# SG for the Rotation Lambda
resource "aws_security_group" "ecs_test_lambda_sg" {
  name        = "secrets-rotation-lambda-sg"
  description = "Allow Lambda to reach RDS and Secrets Manager"
  vpc_id      = aws_vpc.ecs_test_vpc.id

  # Allow outbound to RDS (3306)
  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Or reference the RDS SG ID specifically
  }

  # Allow outbound to VPC Endpoint (443)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Internal VPC traffic only
  }
}

# SG for the VPC Endpoint
resource "aws_security_group" "ecs_test_vpc_endpoint_sg" {
  name        = "secrets-manager-vpce-sg"
  description = "Allow HTTPS from inside VPC"
  vpc_id      = aws_vpc.ecs_test_vpc.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_test_lambda_sg.id]
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_test_app_sg.id]
    description     = "Allow from ECS tasks"
  }
}

/* # Update the Security Group used by your VPC Endpoints
resource "aws_security_group_rule" "vpc_ingress_from_ecs" {
  security_group_id        = aws_security_group.ecs_test_vpc_endpoint_sg.id
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  
  # Allow traffic from the ECS Task Security Group
  source_security_group_id = aws_security_group.ecs_test_app_sg.id
}*/

# Update your EXISTING RDS Security Group
resource "aws_security_group_rule" "ece_test_allow_lambda_rotation" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_test_lambda_sg.id
  security_group_id        = aws_security_group.ecs_test_db_sg.id # Your existing RDS SG
}