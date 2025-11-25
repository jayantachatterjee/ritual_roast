resource "aws_vpc" "ecs_test_vpc" {
    cidr_block           = "10.0.0.0/16"
    enable_dns_hostnames = true
    enable_dns_support   = true

    tags = {
        Name = "ecs-test-vpc"
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