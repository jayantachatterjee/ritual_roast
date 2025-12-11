module "aws_module" {
  source = "./modules/aws-modules"
}

output "codebuild_project_name" {
  value = module.aws_module.codebuild_project_name
}