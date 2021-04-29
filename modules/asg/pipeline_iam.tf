# This IAM role will be used by CodePipeline pipelines
# and associated Lambda functions in the pipeline account.
#
# According to the Terraform documentation at https://www.terraform.io/docs/language/expressions/operators.html
# the && is processed before the ||

data "aws_iam_policy_document" "pipeline_assume_role" {
  count = var.ami_pipeline && var.enabled || var.app_pipeline && var.enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [var.pipeline_aws_account_id]
    }
  }
}

data "aws_iam_policy_document" "pipeline" {
  count = var.ami_pipeline && var.enabled || var.app_pipeline && var.enabled ? 1 : 0

  dynamic "statement" {
    for_each = toset(range(var.app_pipeline ? 1 : 0))
    content {
      sid = "AppBucket"
      actions = [
        "s3:DeleteObjectVersion",
        "s3:ListBucket*",
        "s3:PutObject*",
      ]
      resources = [
        aws_s3_bucket.app[0].arn,
        "${aws_s3_bucket.app[0].arn}/*",
      ]
    }
  }

  statement {
    sid       = "ArtifactBucket"
    actions   = ["s3:GetObject*"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::*-pipeline-${var.pipeline_aws_account_id}/*"]
  }

  statement {
    sid       = "ArtifactKMS"
    actions   = ["kms:Decrypt"]
    resources = ["arn:${data.aws_partition.current.partition}:kms:${data.aws_region.current.name}:${var.pipeline_aws_account_id}:key/*"]
  }

  statement {
    sid = "CloudFormation"
    actions = [
      "cloudformation:DescribeStacks",
      "cloudformation:GetTemplate",
      "cloudformation:UpdateStack",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:cloudformation:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stack/${var.name}/*"]
  }

  statement {
    sid       = "IAM"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.cloudformation[0].arn]
  }

  statement {
    sid     = "ParameterStore"
    actions = ["ssm:PutParameter"]
    resources = concat(
      aws_ssm_parameter.app_version_id[*].arn,
      aws_ssm_parameter.app_version_name[*].arn,
      aws_ssm_parameter.image_id[*].arn,
      aws_ssm_parameter.image_name[*].arn,
    )
  }
}

resource "aws_iam_role" "pipeline" {
  count = var.ami_pipeline && var.enabled || var.app_pipeline && var.enabled ? 1 : 0

  name               = "${var.name}-pipeline"
  assume_role_policy = data.aws_iam_policy_document.pipeline_assume_role[0].json
}

resource "aws_iam_role_policy" "pipeline" {
  count = var.ami_pipeline && var.enabled || var.app_pipeline && var.enabled ? 1 : 0

  role   = aws_iam_role.pipeline[0].name
  policy = data.aws_iam_policy_document.pipeline[0].json
}
