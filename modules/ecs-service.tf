resource "aws_ecs_service" "ecs_test_cluster" {
  name            = "my-app-service"
  cluster         = aws_ecs_cluster.ecs_test_cluster.id
  task_definition = aws_ecs_task_definition.ecs_test_cluster.arn
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
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = false
  }
}

# --- Security Group for ECS Tasks ---
# Only allow traffic from the ALB, not the open internet
resource "aws_security_group" "ecs_tasks_sg" {
  name        = "my-ecs-tasks-sg"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # Allow only ALB
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}