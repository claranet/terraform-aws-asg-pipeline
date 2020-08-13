data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_security_group" "this" {
  name   = var.name
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_alb" "this" {
  name            = var.name
  security_groups = [aws_security_group.this.id]
  subnets         = var.subnet_ids
}

resource "aws_alb_target_group" "this" {
  deregistration_delay = 5
  name                 = var.name
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
}

resource "aws_alb_listener" "this" {
  load_balancer_arn = aws_alb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.this.arn
  }
}

module "instance_profile" {
  source = "git::https://gitlab.com/claranet-pcp/terraform/aws/tf-aws-iam-instance-profile.git?ref=v5.0.0"

  name                = "${var.name}-ec2"
  ec2_describe        = true
  s3_readonly         = true
  s3_read_buckets     = [module.asg.app_location.bucket]
  ssm_managed         = true
  ssm_session_manager = true
}

resource "aws_iam_role_policy" "complete_lifecyle_action" {
  role = module.instance_profile.role_id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "autoscaling:CompleteLifecycleAction"
        # Don't depend on the ASG module for this policy because the
        # ASG module needs this policy to be in place for it to work.
        Resource = "arn:aws:autoscaling:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/${var.name}"
      }
    ]
  })
}

module "asg" {
  source = "../../modules/asg"

  name                    = var.name
  instance_profile_arn    = module.instance_profile.profile_arn
  instance_type           = "t3a.nano"
  min_size                = 1
  max_size                = 2
  pipeline_auto_deploy    = var.pipeline_auto_deploy
  pipeline_aws_account_id = var.pipeline_aws_account_id
  pipeline_target_name    = var.name
  target_group_arns       = [aws_alb_target_group.this.arn]
  security_group_ids      = [aws_security_group.this.id]

  lifecycle_hooks = [{
    DefaultResult       = "ABANDON"
    HeartbeatTimeout    = 60 * 15
    LifecycleHookName   = "launch"
    LifecycleTransition = "autoscaling:EC2_INSTANCE_LAUNCHING"
  }]

  user_data = templatefile("${path.module}/userdata.sh.tmpl", {
    app_location        = module.asg.app_location,
    lifecycle_hook_name = "launch"
  })
}

resource "aws_autoscaling_policy" "this" {
  autoscaling_group_name = module.asg.asg_name
  name                   = "cpu-target-tracking"
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 80
  }
}
