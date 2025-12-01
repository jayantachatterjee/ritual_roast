# --- 1. The ECS Cluster ---
resource "aws_ecs_cluster" "ecs_test_cluster" {
  name = "my-app-cluster"

  # Optional: Enable CloudWatch Container Insights for better metrics
  # (Costs extra but provides CPU/Memory usage at the cluster level)
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# --- 2. Capacity Providers (Fargate & Fargate Spot) ---
# This explicitly links the cluster to Fargate strategies.
resource "aws_ecs_cluster_capacity_providers" "ecs_test_cluster_capacity_providers" {
  cluster_name = aws_ecs_cluster.ecs_test_cluster.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  # Default Strategy: If a service doesn't specify otherwise, 
  # it will use 100% standard Fargate (not Spot).
  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}