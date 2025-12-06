# --- Application Load Balancer ---
resource "aws_lb" "ecs_test_app_alb" {
  name               = "ecs-test-my-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_test_lb_sg.id]
  subnets            = aws_subnet.ecs_test_public_subnet[*].id # List of public subnet IDs
}

# --- Target Group ---
resource "aws_lb_target_group" "ecs_test_target_group" {
  name        = "ecs-test-my-app-tg"
  port        = 80          # The port your container listens on
  protocol    = "HTTP"
  vpc_id      = aws_vpc.ecs_test_vpc.id
  target_type = "ip"          # REQUIRED for Fargate

  health_check {
    path                = "/" # Or /health, /status, etc.
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# --- Listener ---
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ecs_test_app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_test_target_group.arn
  }
}