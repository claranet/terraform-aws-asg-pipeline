# This CloudFormation stack is what creates the Auto Scaling Group
# and associated resource. It uses SSM parameters as inputs to control
# the AMI and app version used by the EC2 instances in the ASG.

resource "aws_cloudformation_stack" "this" {
  name         = var.name
  iam_role_arn = local.cfn_role_arn
  template_body = trimspace(templatefile("${path.module}/cfn.yaml.tpl", {
    access_control       = random_string.access_control.result
    detailed_monitoring  = var.detailed_monitoring
    instance_profile_arn = var.instance_profile_arn
    instance_type        = var.instance_type
    key_name             = var.key_name
    lifecycle_hooks      = var.lifecycle_hooks
    max_size             = var.max_size
    min_size             = var.min_size
    name                 = var.name
    rolling_update_policy = merge({
      MaxBatchSize                  = var.max_size
      MinInstancesInService         = min(var.min_size, var.max_size - 1)
      MinSuccessfulInstancesPercent = 100
      PauseTime                     = "PT1H"
    }, var.rolling_update_policy)
    security_group_ids = var.security_group_ids
    subnet_ids         = var.subnet_ids
    tags               = var.tags
    target_group_arns  = var.target_group_arns
    user_data          = var.user_data
  }))
  parameters = {
    AppVersionId   = aws_ssm_parameter.app_version_id.name
    AppVersionName = aws_ssm_parameter.app_version_name.name
    ImageId        = aws_ssm_parameter.image_id.name
    ImageName      = aws_ssm_parameter.image_name.name
  }
}
