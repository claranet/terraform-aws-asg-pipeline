data "aws_iam_instance_profile" "this" {
  count = var.enabled ? 1 : 0
  name  = split("/", var.instance_profile_arn)[1]
}

data "aws_iam_policy_document" "cloudformation_assume_role" {
  count = var.enabled ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["cloudformation.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "cloudformation" {
  count = var.enabled ? 1 : 0
  # Allow reading the input parameters from SSM.

  dynamic "statement" {
    for_each = toset(range(var.ami_pipeline || var.app_pipeline ? 1 : 0))
    content {
      sid     = "ReadParameters"
      actions = ["ssm:GetParameters"]
      resources = concat(
        aws_ssm_parameter.app_version_id[*].arn,
        aws_ssm_parameter.app_version_name[*].arn,
        aws_ssm_parameter.image_id[*].arn,
        aws_ssm_parameter.image_name[*].arn,
      )
    }
  }

  statement {
    sid     = "InvokeLambda"
    actions = ["lambda:Invoke*"]
    resources = [
      module.cfn_params_lambda.arn,
      module.cfn_wait_lambda.arn,
    ]
  }

  # Allow describing various resources.
  # IAM does not support specific resources or conditions for these actions.

  statement {
    sid = "DescribeThings"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLifecycleHooks",
      "autoscaling:DescribeLoadBalancerTargetGroups",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeScheduledActions",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribeSubnets",
    ]
    resources = ["*"]
  }

  # Allow managing launch templates. Specific resource ARNs cannot be used
  # because the launch template is created by this role, and the ARN does
  # not include any predictable identifiers. Tag conditions are not used
  # because CloudFormation does not support tagging launch templates.

  statement {
    sid = "ManageLaunchTemplate"
    actions = [
      "ec2:CreateLaunchTemplate",
      "ec2:CreateLaunchTemplateVersion",
      "ec2:DeleteLaunchTemplate",
      "ec2:DescribeLaunchTemplates",
    ]
    resources = ["*"]
  }

  # Allow the launch template to run instances with tags.
  # https://aws.amazon.com/premiumsupport/knowledge-center/iam-policy-tags-restrict/

  statement {
    sid     = "RunInstances"
    actions = ["ec2:RunInstances"]
    resources = [
      "arn:aws:ec2:*::image/*",
      "arn:aws:ec2:*::snapshot/*",
      "arn:aws:ec2:*:*:key-pair/*",
      "arn:aws:ec2:*:*:launch-template/*",
      "arn:aws:ec2:*:*:network-interface/*",
      "arn:aws:ec2:*:*:security-group/*",
      "arn:aws:ec2:*:*:subnet/*",
      "arn:aws:ec2:*:*:volume/*",
    ]
  }

  statement {
    sid       = "RunInstancesWithTag"
    actions   = ["ec2:RunInstances"]
    resources = ["arn:aws:ec2:*:*:instance/*"]
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:TagKeys"
      values   = ["AccessControl"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/AccessControl"
      values   = [random_string.access_control[0].result]
    }
  }

  statement {
    sid       = "RunInstancesCreateTags"
    actions   = ["ec2:CreateTags"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["RunInstances"]
    }
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:TagKeys"
      values   = ["AccessControl"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/AccessControl"
      values   = [random_string.access_control[0].result]
    }
  }

  # Allow the launch template to use the instance profile role.

  statement {
    sid       = "PassRole"
    actions   = ["iam:PassRole"]
    resources = [data.aws_iam_instance_profile.this[0].role_arn]
  }

  # Allow managing auto scaling groups. It will include the AccessControl
  # tag when creating the ASG, and then check for it when performing other
  # operations against it.

  statement {
    sid = "CreateAutoScalingGroup"
    actions = [
      "autoscaling:CreateAutoScalingGroup",
      "autoscaling:CreateOrUpdateTags",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:autoscaling:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/${var.name}"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/AccessControl"
      values   = [random_string.access_control[0].result]
    }
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:TagKeys"
      values   = ["AccessControl"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/AccessControl"
      values   = [random_string.access_control[0].result]
    }
  }

  statement {
    sid = "ManageAutoScalingGroup"
    actions = [
      "autoscaling:AttachLoadBalancerTargetGroups",
      "autoscaling:CreateOrUpdateTags",
      "autoscaling:DeleteAutoScalingGroup",
      "autoscaling:DeleteLifecycleHook",
      "autoscaling:DeleteTags",
      "autoscaling:DetachLoadBalancerTargetGroups",
      "autoscaling:DisableMetricsCollection",
      "autoscaling:EnableMetricsCollection",
      "autoscaling:PutLifecycleHook",
      "autoscaling:ResumeProcesses",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:SuspendProcesses",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/AccessControl"
      values   = [random_string.access_control[0].result]
    }
  }
}

resource "aws_iam_role" "cloudformation" {
  count              = var.enabled ? 1 : 0
  name               = "${var.name}-cloudformation"
  assume_role_policy = data.aws_iam_policy_document.cloudformation_assume_role[0].json
}

resource "aws_iam_role_policy" "cloudformation" {
  count  = var.enabled ? 1 : 0
  role   = aws_iam_role.cloudformation[0].name
  policy = data.aws_iam_policy_document.cloudformation[0].json
}

# CloudFormation will try to use the IAM role straight away,
# but the policy needs to be attached first, which is
# eventually consistent, so introduce a delay here.

resource "time_sleep" "cloudformation_iam_role" {
  count           = var.enabled ? 1 : 0
  create_duration = "15s"
  triggers = {
    arn         = aws_iam_role.cloudformation[0].arn
    name        = aws_iam_role_policy.cloudformation[0].role         # depend on the policy attachment
    policy_hash = sha1(aws_iam_role_policy.cloudformation[0].policy) # depend on the policy content
  }
}

locals {
  cfn_role_arn = var.enabled ? time_sleep.cloudformation_iam_role[0].triggers["arn"] : ""
}
