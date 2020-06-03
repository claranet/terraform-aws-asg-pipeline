data "aws_iam_policy_document" "lambda" {
  statement {
    sid       = "AssumeRoleInTargetAccounts"
    actions   = ["sts:AssumeRole"]
    resources = [for target in var.targets : target.assume_role.arn]
  }

  statement {
    sid       = "CodePipeline"
    effect    = "Allow"
    actions   = ["codepipeline:PutJobFailureResult", "codepipeline:PutJobSuccessResult"]
    resources = ["*"]
  }

  statement {
    sid       = "EC2"
    effect    = "Allow"
    actions   = ["ec2:DescribeImages"]
    resources = ["*"]
  }
}
