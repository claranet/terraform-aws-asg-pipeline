data "aws_iam_instance_profile" "this" {
  name = split("/", var.instance_profile_arn)[1]
}

data "aws_iam_policy_document" "cloudformation_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["cloudformation.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "cloudformation" {
  # Allow reading the input parameters from SSM.

  statement {
    sid     = "ReadParameters"
    actions = ["ssm:GetParameters"]
    resources = [
      aws_ssm_parameter.app_version_id.arn,
      aws_ssm_parameter.app_version_name.arn,
      aws_ssm_parameter.image_id.arn,
      aws_ssm_parameter.image_name.arn,
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
      values   = [random_string.access_control.result]
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
      values   = [random_string.access_control.result]
    }
  }

  # Allow the launch template to use the instance profile role.

  statement {
    sid       = "PassRole"
    actions   = ["iam:PassRole"]
    resources = [data.aws_iam_instance_profile.this.role_arn]
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
      values   = [random_string.access_control.result]
    }
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:TagKeys"
      values   = ["AccessControl"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/AccessControl"
      values   = [random_string.access_control.result]
    }
  }

  statement {
    sid = "ManageAutoScalingGroup"
    actions = [
      "autoscaling:AttachLoadBalancerTargetGroups",
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
      values   = [random_string.access_control.result]
    }
  }
}

resource "aws_iam_role" "cloudformation" {
  name               = "${var.name}-cloudformation"
  assume_role_policy = data.aws_iam_policy_document.cloudformation_assume_role.json
}

resource "aws_iam_role_policy" "cloudformation" {
  role   = aws_iam_role.cloudformation.name
  policy = data.aws_iam_policy_document.cloudformation.json
}

# CloudFormation will try to use the IAM role straight away,
# but the policy needs to be attached first, which is
# eventually consistent, so introduce a delay here.

resource "time_sleep" "cloudformation_iam_role" {
  create_duration = "15s"
  triggers = {
    arn         = aws_iam_role.cloudformation.arn
    name        = aws_iam_role_policy.cloudformation.role         # depend on the policy attachment
    policy_hash = sha1(aws_iam_role_policy.cloudformation.policy) # depend on the policy content
  }
}

locals {
  cfn_role_arn = time_sleep.cloudformation_iam_role.triggers["arn"]
}
