# Create a CloudFormation custom resource Lambda function
# to wait for instances in the Terminating:Wait state.

module "cfn_wait_lambda" {
  source  = "raymondbutcher/lambda-builder/aws"
  version = "1.1.0"

  enabled = var.enabled

  function_name = "${var.name}-cfn-wait"
  handler       = "lambda.lambda_handler"
  runtime       = "python3.7"
  memory_size   = 128
  timeout       = 60 * 15

  build_mode = "FILENAME"
  source_dir = "${path.module}/cfn_wait"
  filename   = "${path.module}/cfn_wait_lambda.zip"

  role_cloudwatch_logs       = true
  role_custom_policies       = [data.aws_iam_policy_document.cfn_wait_lambda.json]
  role_custom_policies_count = 1
}

data "aws_iam_policy_document" "cfn_wait_lambda" {
  count = var.enabled ? 1 : 0
  statement {
    effect    = "Allow"
    actions   = ["autoscaling:DescribeAutoScalingGroups"]
    resources = ["*"]
  }
}
