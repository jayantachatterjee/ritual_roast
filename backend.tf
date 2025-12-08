terraform {
  backend "s3" {
    # Replace with the values from Step 1
    bucket         = "my-unique-app-terraform-state-12345"
    key            = "prod/terraform.tfstate" # The path within the bucket
    region         = "us-east-1"
    
    # Enable Locking
    dynamodb_table = "my-app-terraform-locks"
    encrypt        = true
  }
}