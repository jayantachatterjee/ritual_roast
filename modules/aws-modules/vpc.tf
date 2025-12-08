resource "aws_vpc" "ecs_test_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "ecs-vpc"
  }
}

resource "aws_internet_gateway" "ecs_test_igw" {
  vpc_id = aws_vpc.ecs_test_vpc.id

  tags = {
    Name = "ecs-test-igw"
  }
}

resource "aws_route_table" "ecs_test_public" {
  vpc_id = aws_vpc.ecs_test_vpc.id

  tags = {
    Name = "ecs-test-public-rt"
  }
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.ecs_test_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ecs_test_igw.id
}

resource "aws_route_table" "ecs_test_private" {
  vpc_id = aws_vpc.ecs_test_vpc.id

  tags = {
    Name = "ecs-test-private-rt"
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
  route_table_ids = aws_route_table.ecs_test_private[*].id
}

resource "aws_vpc_endpoint" "secrets" {
  vpc_id              = aws_vpc.ecs_test_vpc.id
  service_name        = "com.amazonaws.ap-southeast-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.ecs_test_private_app_subnet[*].id
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.ecs_test_vpc_endpoint_sg.id]
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.ecs_test_vpc.id
  service_name        = "com.amazonaws.ap-southeast-1.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.ecs_test_private_app_subnet[*].id
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.ecs_test_vpc_endpoint_sg.id]
}
