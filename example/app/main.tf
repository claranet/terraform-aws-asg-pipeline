# Everything related to the app Auto Scaling Group in this environment.

module "instance_profile" {
  source = "git::https://gitlab.com/claranet-pcp/terraform/aws/tf-aws-iam-instance-profile.git?ref=v5.0.0"

  name                = "${var.project_name}-${var.environment}-ec2"
  ec2_describe        = true
  s3_readonly         = true
  s3_read_buckets     = [module.asg.app_location.bucket]
  ssm_managed         = true
  ssm_session_manager = true
}

module "asg" {
  source = "./modules/asg"

  name                    = "${var.project_name}-${var.environment}"
  instance_profile_arn    = module.instance_profile.profile_arn
  instance_type           = "t3a.nano"
  max_size                = 2
  min_size                = 1
  pipeline_auto_deploy    = var.pipeline_auto_deploy
  pipeline_aws_account_id = var.pipeline_aws_account_id
  pipeline_target_name    = title(var.environment)
  user_data               = <<-EOF
    #!/bin/bash
    set -xeuo pipefail
    instance_id=$(curl -sS http://169.254.169.254/latest/meta-data/instance-id)
    region=$(curl -sS http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//')
    app_version=$(aws ec2 describe-tags --region $region --filters \"Name=resource-id,Values=$instance_id\" --query \"Tags[?Key=='AppVersion'].Value\" --output text)
    aws s3api get-object --bucket ${module.asg.app_location.bucket} --key ${module.asg.app_location.key} --version-id $app_version /tmp/app.zip
    unzip /tmp/app.zip
  EOF
}
