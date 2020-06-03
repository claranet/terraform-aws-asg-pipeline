resource "aws_codepipeline" "this" {
  name     = var.name
  role_arn = local.codepipeline_role_arn

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.pipeline.bucket
    encryption_key {
      id   = var.kms_key_arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      output_artifacts = ["source"]

      category = "Source"
      owner    = "AWS"
      provider = "S3"
      version  = "1"

      configuration = {
        PollForSourceChanges = "true"
        S3Bucket             = var.source_location.bucket
        S3ObjectKey          = var.source_location.key
      }
    }
  }

  dynamic "stage" {
    for_each = var.targets
    iterator = each

    content {
      name = each.value.name

      # Approval step.
      # This is skipped when the target has "auto deploy" enabled.
      dynamic "action" {
        for_each = toset(range(each.value.auto_deploy ? 0 : 1))
        content {
          name      = "Approve"
          run_order = "1"

          category = "Approval"
          owner    = "AWS"
          provider = "Manual"
          version  = "1"

          configuration = {
            CustomData = "Approve deployment to ${each.value.name}"
          }
        }
      }

      # Prepare deployment step for AMI pipelines.
      # Downloads the CFN stack template and writes it to the S3 output
      # artifact location, used by the subsequent CFN stack update action.
      # Downloads the Packer manifest input artifact, extracts the new
      # image id from it, and then updates the SSM parameters used by
      # the CFN stack template.
      dynamic "action" {
        for_each = toset(range(var.type == "ami" ? 1 : 0))
        content {
          name             = "Prepare"
          run_order        = "2"
          input_artifacts  = ["source"]
          output_artifacts = ["${each.value.name}_cloudformation_template"]

          category = "Invoke"
          owner    = "AWS"
          provider = "Lambda"
          version  = "1"

          configuration = {
            FunctionName = module.prepare_ami_deployment_lambda.function_name
            UserParameters = jsonencode({
              AssumeRoleArn = each.value.assume_role.arn
              ParameterNames = {
                ImageId   = each.value.ssm_params.image_id.name
                ImageName = each.value.ssm_params.image_name.name
              }
              StackName        = each.value.cfn_stack.name
              TemplateFilename = "cfn.yaml"
            })
          }
        }
      }

      # Prepare deployment step for app pipelines.
      # Downloads the CFN stack template and writes it to the S3 output
      # artifact location, used by the subsequent CFN stack update action.
      # Copies the app release from the pipeline artifacts S3 bucket
      # to the target S3 bucket, and then updates the SSM parameters
      # used by the CFN stack template.
      dynamic "action" {
        for_each = toset(range(var.type == "app" ? 1 : 0))
        content {
          name             = "Prepare"
          run_order        = "2"
          input_artifacts  = ["source"]
          output_artifacts = ["${each.value.name}_cloudformation_template"]

          category = "Invoke"
          owner    = "AWS"
          provider = "Lambda"
          version  = "1"

          configuration = {
            FunctionName = module.prepare_app_deployment_lambda.function_name
            UserParameters = jsonencode({
              AppLocation = {
                Bucket = each.value.app_location.bucket
                Key    = each.value.app_location.key
              }
              AssumeRoleArn = each.value.assume_role.arn
              ParameterNames = {
                AppVersionId   = each.value.ssm_params.app_version_id.name
                AppVersionName = each.value.ssm_params.app_version_name.name
              }
              StackName        = each.value.cfn_stack.name
              TemplateFilename = "cfn.yaml"
            })
          }
        }
      }

      # Cloudformation stack update step.
      # Uses the output artifact from the Lambda function which contains
      # the CFN template. The CFN template parameters use SSM parameters,
      # which get updated by Lambda in the previous action. This approach
      # lets 2 similar pipelines update the same CFN stack without getting
      # input parameters mixed up, but if they run at the same time then
      # one will error (you can just click retry, and this can be improved
      # later with more a fancy Lambda function or Step Function).
      action {
        name            = "Deploy"
        run_order       = "3"
        input_artifacts = ["${each.value.name}_cloudformation_template"]

        category = "Deploy"
        owner    = "AWS"
        provider = "CloudFormation"
        version  = "1"

        configuration = {
          ActionMode         = "CREATE_UPDATE"
          RoleArn            = each.value.cfn_role.arn
          StackName          = each.value.cfn_stack.name
          TemplatePath       = "${each.value.name}_cloudformation_template::cfn.yaml"
          ParameterOverrides = jsonencode(each.value.cfn_stack.params)
        }

        role_arn = each.value.assume_role.arn
      }

      # Cleanup step for app pipelines.
      # Deletes old app versions from the target S3 bucket.
      dynamic "action" {
        for_each = toset(range(var.type == "app" ? 1 : 0))
        content {
          name      = "Cleanup"
          run_order = "4"

          category = "Invoke"
          owner    = "AWS"
          provider = "Lambda"
          version  = "1"

          configuration = {
            FunctionName = module.cleanup_app_deployment_lambda.function_name
            UserParameters = jsonencode({
              AppLocation = {
                Bucket = each.value.app_location.bucket
                Key    = each.value.app_location.key
              }
              AssumeRoleArn = each.value.assume_role.arn
              StackName     = each.value.cfn_stack.name
            })
          }
        }
      }
    }
  }
}
