module "prepare_ami_deployment_lambda" {
  source  = "raymondbutcher/lambda-builder/aws"
  version = "1.0.2"

  enabled = var.type == "ami"

  function_name = "${var.name}-prepare-deployment"
  handler       = "prepare_ami_deployment.lambda_handler"
  runtime       = "python3.6"
  filename      = ".terraform/prepare-ami-deployment-lambda.zip"
  timeout       = 30

  # Enable build functionality.
  build_mode = "FILENAME"
  source_dir = "${path.module}/lambda"

  # Create and use a role with CloudWatch Logs permissions,
  # and attach a custom policy.
  role_cloudwatch_logs       = true
  role_custom_policies       = [data.aws_iam_policy_document.lambda.json]
  role_custom_policies_count = 1
}


module "prepare_app_deployment_lambda" {
  source  = "raymondbutcher/lambda-builder/aws"
  version = "1.0.2"

  enabled = var.type == "app"

  function_name = "${var.name}-prepare-deployment"
  handler       = "prepare_app_deployment.lambda_handler"
  runtime       = "python3.6"
  filename      = ".terraform/prepare-app-deployment-lambda.zip"
  timeout       = 300

  # Enable build functionality.
  build_mode = "FILENAME"
  source_dir = "${path.module}/lambda"

  # Create and use a role with CloudWatch Logs permissions,
  # and attach a custom policy.
  role_cloudwatch_logs       = true
  role_custom_policies       = [data.aws_iam_policy_document.lambda.json]
  role_custom_policies_count = 1
}


module "cleanup_app_deployment_lambda" {
  source  = "raymondbutcher/lambda-builder/aws"
  version = "1.0.2"

  enabled = var.type == "app"

  function_name = "${var.name}-cleanup-deployment"
  handler       = "cleanup_app_deployment.lambda_handler"
  runtime       = "python3.6"
  filename      = ".terraform/cleanup-app-deployment-lambda.zip"
  timeout       = 30

  # Enable build functionality.
  build_mode = "FILENAME"
  source_dir = "${path.module}/lambda"

  # Create and use a role with CloudWatch Logs permissions,
  # and attach a custom policy.
  role_cloudwatch_logs       = true
  role_custom_policies       = [data.aws_iam_policy_document.lambda.json]
  role_custom_policies_count = 1
}
