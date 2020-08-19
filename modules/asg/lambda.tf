# Create a CloudFormation custom resource Lambda function
# to return dynamic parameter values.

locals {
  default_ami_ssm_parameter = "/aws/service/ami-amazon-linux-latest/amzn-ami-hvm-x86_64-ebs"
}

module "cfn_params_lambda" {
  source  = "raymondbutcher/lambda-builder/aws"
  version = "1.0.2"

  function_name = "${var.name}-cfn-params"
  handler       = "lambda.lambda_handler"
  runtime       = "python3.7"
  memory_size   = 128
  timeout       = 30

  build_mode = "FILENAME"
  source_dir = "${path.module}/cfn_params"
  filename   = "${path.module}/cfn_params_lambda.zip"

  role_cloudwatch_logs       = true
  role_custom_policies       = [data.aws_iam_policy_document.cfn_params_lambda.json]
  role_custom_policies_count = 1

  environment = {
    variables = {
      AUTO_SCALING_GROUP_NAME   = var.name
      DEFAULT_AMI_SSM_PARAMETER = local.default_ami_ssm_parameter
    }
  }
}

data "aws_iam_policy_document" "cfn_params_lambda" {
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

resource "time_sleep" "cfn_params_lambda" {
  create_duration = "120s" # because CFN sometimes calls Lambda before it's ready and it breaks
  triggers = {
    arn = module.cfn_params_lambda.arn
  }
}

locals {
  cfn_params_lambda_arn = time_sleep.cfn_params_lambda.triggers["arn"]
}

# Create a Lambda function to tell CloudFormation when an auto
# scaling group instance is healthy according to its target groups.

module "cfn_signal_lambda" {
  source  = "raymondbutcher/lambda-builder/aws"
  version = "1.0.2"

  function_name = "${var.name}-cfn-signal"
  handler       = "lambda.lambda_handler"
  runtime       = "python3.7"
  memory_size   = 128
  timeout       = 60 * 15

  build_mode = "FILENAME"
  source_dir = "${path.module}/cfn_signal"
  filename   = "${path.module}/cfn_signal_lambda.zip"

  role_cloudwatch_logs       = true
  role_custom_policies       = [data.aws_iam_policy_document.cfn_signal_lambda.json]
  role_custom_policies_count = 1

  environment = {
    variables = {
      LOGICAL_RESOURCE_ID = "AutoScalingGroup" # This must match the resource in the CFN template.
      STACK_NAME          = var.name
      TARGET_GROUP_ARNS   = jsonencode(var.target_group_arns)
    }
  }
}

data "aws_iam_policy_document" "cfn_signal_lambda" {
  statement {
    effect    = "Allow"
    actions   = ["elasticloadbalancing:DescribeTargetGroups", "elasticloadbalancing:DescribeTargetHealth"]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["cloudformation:SignalResource"]
    resources = ["arn:${data.aws_partition.current.partition}:cloudformation:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stack/${var.name}/*"]
  }
}

# Invoke the function for each instance launched by the auto scaling group.

resource "aws_cloudwatch_event_rule" "cfn_signal" {
  name = module.cfn_signal_lambda.function_name
  event_pattern = jsonencode({
    source      = ["aws.autoscaling"]
    detail-type = ["EC2 Instance Launch Successful"]
    detail = {
      AutoScalingGroupName = [var.name]
    }
  })
}

resource "aws_cloudwatch_event_target" "cfn_signal" {
  target_id = "lambda"
  rule      = aws_cloudwatch_event_rule.cfn_signal.name
  arn       = module.cfn_signal_lambda.arn
}

resource "aws_lambda_permission" "cfn_signal" {
  statement_id  = "cloudwatch-event-rule"
  action        = "lambda:InvokeFunction"
  function_name = module.cfn_signal_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cfn_signal.arn
}
