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