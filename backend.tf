terraform {
  backend "s3" {
    # Replace with the values from Step 1
    bucket         = "my-unique-app-ritual-roast-terraform-state-123"
    key            = "prod/terraform.tfstate" # The path within the bucket
    region         = "ap-southeast-1"
    
    # Enable Locking
    dynamodb_table = "my-app-terraform-locks"
    encrypt        = true
  }
}