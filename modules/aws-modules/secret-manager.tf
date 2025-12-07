# --- 1. Generate a Random Initial Password ---
# This is used ONLY for the very first creation. 
# After that, Secrets Manager takes over.
resource "random_password" "ecs_test_master_password" {
  length           = 16
  special          = true
  override_special = "_!%^"
}

# --- 2. Create the Secret Container ---
resource "aws_secretsmanager_secret" "ecs_test_rds_credentials" {
  name        = "ritualroast-ecs-db-secret"
  description = "Credentials for the private RDS MySQL instance"

  # Allow the secret to be deleted immediately for testing (set to 7-30 days for prod)
  recovery_window_in_days = 0
}

# --- 3. Store the Secret Data ---
# We use jsonencode so the Rotation Lambda can parse the host and credentials
resource "aws_secretsmanager_secret_version" "ecs_test_rds_credentials" {
  secret_id = aws_secretsmanager_secret.ecs_test_rds_credentials.id
  secret_string = jsonencode({
    username = aws_db_instance.ecs_test_db_instance.username
    password = random_password.ecs_test_master_password.result
    engine   = "mysql"
    host     = aws_db_instance.ecs_test_db_instance.address
    port     = 3306
    dbname   = aws_db_instance.ecs_test_db_instance.db_name
  })
}

# --- 4. Deploy the Rotation Lambda ---
# We use the official AWS Serverless Repo "MySQL Rotation" application
data "aws_serverlessapplicationrepository_application" "rotator" {
  application_id = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSMySQLRotationSingleUser"
}

resource "aws_serverlessapplicationrepository_cloudformation_stack" "rotate_stack" {
  name             = "Rotate-RDS-MySQL"
  application_id   = data.aws_serverlessapplicationrepository_application.rotator.application_id
  semantic_version = data.aws_serverlessapplicationrepository_application.rotator.semantic_version
  capabilities     = data.aws_serverlessapplicationrepository_application.rotator.required_capabilities

  parameters = {
    endpoint            = "https://secretsmanager.ap-southeast-1.amazonaws.com"
    functionName        = "MyRDS-Rotator-Function"
    vpcSubnetIds        = join(",", aws_db_subnet_group.ecs_test_db_subnet_group.subnet_ids) # Must be same subnets as RDS
    vpcSecurityGroupIds = aws_security_group.ecs_test_db_sg.id
  }
}

# --- 5. Attach Rotation to Secret ---
resource "aws_secretsmanager_secret_rotation" "rotation" {
  secret_id           = aws_secretsmanager_secret.ecs_test_rds_credentials.id
  rotation_lambda_arn = aws_serverlessapplicationrepository_cloudformation_stack.rotate_stack.outputs.RotationLambdaARN

  rotation_rules {
    automatically_after_days = 30
  }
}
