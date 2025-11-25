data "aws_availability_zones" "available" {
    state = "available"
}

resource "aws_subnet" "ecs_test_public_subnet" {
    vpc_id                  = aws_vpc.ecs_test_vpc.id
    count                   = 2
    cidr_block              = cidrsubnet(aws_vpc.ecs_test_vpc.cidr_block, 8, count.index)
    availability_zone       = data.aws_availability_zones.available.names[count.index]
    map_public_ip_on_launch = true
  
  tags = {
    Name = "ecs-test-public-subnet-${count.index + 1}"
  }
}

resource "aws_route_table_association" "ecs_test_public_subnet_association" {
    count          = 2
    subnet_id      = aws_subnet.ecs_test_public_subnet[count.index].id
    route_table_id = aws_route_table.ecs_test_public.id
}

resource "aws_subnet" "ecs_test_private_app_subnet" {
    vpc_id            = aws_vpc.ecs_test_vpc.id
    count             = 2
    cidr_block        = cidrsubnet(aws_vpc.ecs_test_vpc.cidr_block, 8, count.index + 2)
    availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = {
    Name = "ecs-test-private-app-subnet-${count.index + 1}"
  }
  
}

resource "aws_route_table_association" "ecs_test_private_app_subnet_association" {
    count          = 2
    subnet_id      = aws_subnet.ecs_test_private_app_subnet[count.index].id
    route_table_id = aws_route_table.ecs_test_private.id
  
}

resource "aws_subnet" "ecs_test_private_db_subnet" {
    vpc_id            = aws_vpc.ecs_test_vpc.id
    count             = 2
    cidr_block        = cidrsubnet(aws_vpc.ecs_test_vpc.cidr_block, 8, count.index + 4)
    availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = {
    Name = "ecs-test-private-db-subnet-${count.index + 1}"
  }
  
}

resource "aws_route_table_association" "ecs_test_private_db_subnet_association" {
    count          = 2
    subnet_id      = aws_subnet.ecs_test_private_db_subnet[count.index].id
    route_table_id = aws_route_table.ecs_test_private.id
  
}