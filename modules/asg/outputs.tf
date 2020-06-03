output "app_location" {
  description = "The S3 location where the pipeline will put app release zip files."
  value = {
    bucket = aws_s3_bucket.app.id
    key    = "app.zip"
  }
}

output "asg_name" {
  description = "The Auto Scaling Group name."
  value       = lookup(aws_cloudformation_stack.this.outputs, "AutoScalingGroupName", "")
}

output "pipeline_target" {
  description = "Information required by a pipeline to deploy to this Auto Scaling Group."
  value = {
    app_location = {
      bucket = aws_s3_bucket.app.id
      key    = "app.zip"
    }
    assume_role = {
      arn = aws_iam_role.pipeline.arn
    }
    auto_deploy = var.pipeline_auto_deploy
    cfn_role = {
      arn = aws_iam_role.cloudformation.arn
    }
    cfn_stack = {
      arn    = aws_cloudformation_stack.this.id
      name   = aws_cloudformation_stack.this.name
      params = aws_cloudformation_stack.this.parameters
    }
    name = var.pipeline_target_name
    ssm_params = {
      app_version_id = {
        arn  = aws_ssm_parameter.app_version_id.arn
        name = aws_ssm_parameter.app_version_id.name
      }
      app_version_name = {
        arn  = aws_ssm_parameter.app_version_name.arn
        name = aws_ssm_parameter.app_version_name.name
      }
      image_id = {
        arn  = aws_ssm_parameter.image_id.arn
        name = aws_ssm_parameter.image_id.name
      }
      image_name = {
        arn  = aws_ssm_parameter.image_name.arn
        name = aws_ssm_parameter.image_name.name
      }
    }
  }
}
