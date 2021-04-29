# Create a CloudFormation custom resource Lambda function
# to return dynamic parameter values.

locals {
  default_ami_ssm_parameter = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-ebs"
}

module "cfn_params_lambda" {
  source  = "raymondbutcher/lambda-builder/aws"
  version = "1.1.0"

  enabled = var.enabled

  function_name = "${var.name}-cfn-params"
  handler       = "lambda.lambda_handler"
  runtime       = "python3.7"
  memory_size   = 128
  timeout       = 30

  build_mode = "FILENAME"
  source_dir = "${path.module}/cfn_params"
  filename   = "${path.module}/cfn_params_lambda.zip"

  role_cloudwatch_logs       = true
  role_custom_policies       = var.enabled ? [data.aws_iam_policy_document.cfn_params_lambda[0].json] : []
  role_custom_policies_count = 1

  environment = {
    variables = {
      AUTO_SCALING_GROUP_NAME   = var.name
      DEFAULT_AMI_SSM_PARAMETER = local.default_ami_ssm_parameter
    }
  }
}

data "aws_iam_policy_document" "cfn_params_lambda" {
  count = var.enabled ? 1 : 0
  statement {
    effect    = "Allow"
    actions   = ["autoscaling:DescribeAutoScalingGroups"]
    resources = ["*"]
  }

  statement {
    effect  = "Allow"
    actions = ["ssm:GetParameter"]
    resources = [format(
      "arn:%s:ssm:%s:*:parameter/%s",
      data.aws_partition.current.partition,
      data.aws_region.current.name,
      trimprefix(local.default_ami_ssm_parameter, "/"),
    )]
  }
}
