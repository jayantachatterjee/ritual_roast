resource "aws_db_subnet_group" "ecs_test_db_subnet_group" {
  name       = "ecs_test_db_subnet_group"
  subnet_ids = aws_subnet.ecs_test_private_db_subnet[*].id

  tags = {
    Name = "ecs_test_db_subnet_group"
  }
}

resource "aws_db_instance" "ecs_test_db_instance" {
  identifier              = "ecs-test-db-instance"
  allocated_storage       = 20
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  db_name                 = "ritualroast"       
  username                = "admin"
  password                = "admin123"
  db_subnet_group_name    = aws_db_subnet_group.ecs_test_db_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.ecs_test_db_sg.id]
  skip_final_snapshot     = true
  publicly_accessible     = false
  multi_az                = false
  storage_type           = "gp2"  

  tags = {
    Name = "ecs_test_db_instance"
  }
}