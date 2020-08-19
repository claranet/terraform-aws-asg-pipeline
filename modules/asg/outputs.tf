output "app_location" {
  description = "The S3 location where the pipeline will put app release zip files."
  value = {
    bucket = var.app_pipeline ? aws_s3_bucket.app[0].id : null
    key    = var.app_pipeline ? "app.zip" : null
  }
}

output "asg_name" {
  description = "The Auto Scaling Group name."
  value       = aws_cloudformation_stack.this.outputs.AutoScalingGroupName
}

output "pipeline_target" {
  description = "Information required by a pipeline to deploy to this Auto Scaling Group."
  value = var.app_pipeline || var.ami_pipeline ? {
    app_location = {
      bucket = var.app_pipeline ? aws_s3_bucket.app[0].id : null
      key    = var.app_pipeline ? "app.zip" : null
    }
    assume_role = {
      arn = aws_iam_role.pipeline[0].arn
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
        arn  = var.app_pipeline ? aws_ssm_parameter.app_version_id[0].arn : null
        name = var.app_pipeline ? aws_ssm_parameter.app_version_id[0].name : null
      }
      app_version_name = {
        arn  = var.app_pipeline ? aws_ssm_parameter.app_version_name[0].arn : null
        name = var.app_pipeline ? aws_ssm_parameter.app_version_name[0].name : null
      }
      image_id = {
        arn  = var.ami_pipeline ? aws_ssm_parameter.image_id[0].arn : null
        name = var.ami_pipeline ? aws_ssm_parameter.image_id[0].name : null
      }
      image_name = {
        arn  = var.ami_pipeline ? aws_ssm_parameter.image_name[0].arn : null
        name = var.ami_pipeline ? aws_ssm_parameter.image_name[0].name : null
      }
    }
  } : null
}
