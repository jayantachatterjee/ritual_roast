resource "aws_ecs_service" "ecs_test_cluster" {
  name            = "my-app-service"
  cluster         = aws_ecs_cluster.ecs_test_cluster.id
  # task_definition = aws_ecs_task_definition.ecs_test_cluster.arn
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
}