# Data sources in the nonprod, prod and management accounts.

data "aws_caller_identity" "management" {
  provider = aws.management
}

data "aws_vpc" "nonprod" {
  provider = aws.nonprod
  default  = true
}

data "aws_subnet_ids" "nonprod" {
  provider = aws.nonprod
  vpc_id   = data.aws_vpc.nonprod.id
}

data "aws_vpc" "prod" {
  provider = aws.prod
  default  = true
}

data "aws_subnet_ids" "prod" {
  provider = aws.prod
  vpc_id   = data.aws_vpc.prod.id
}

# Dev and staging ASGs in the nonprod account.

module "asg_dev" {
  source = "./asg"

  providers = {
    aws = aws.nonprod
  }

  name                    = "asg-pipeline-dev"
  pipeline_auto_deploy    = true
  pipeline_aws_account_id = data.aws_caller_identity.management.account_id
  subnet_ids              = data.aws_subnet_ids.nonprod.ids
  vpc_id                  = data.aws_vpc.nonprod.id
}

module "asg_staging" {
  source = "./asg"

  providers = {
    aws = aws.nonprod
  }

  name                    = "asg-pipeline-staging"
  pipeline_auto_deploy    = false
  pipeline_aws_account_id = data.aws_caller_identity.management.account_id
  subnet_ids              = data.aws_subnet_ids.nonprod.ids
  vpc_id                  = data.aws_vpc.nonprod.id
}

# Prod ASG in the prod account.

module "asg_prod" {
  source = "./asg"

  providers = {
    aws = aws.prod
  }

  name                    = "asg-pipeline-prod"
  pipeline_auto_deploy    = false
  pipeline_aws_account_id = data.aws_caller_identity.management.account_id
  subnet_ids              = data.aws_subnet_ids.prod.ids
  vpc_id                  = data.aws_vpc.prod.id
}

# AMI and app pipelines in the management account.

# module "pipelines" {
#   source = "./pipelines"

#   name = "asg-pipeline"
#   targets = [
#     module.asg_dev.pipeline_target,
#     module.asg_staging.pipeline_target,
#     module.asg_prod.pipeline_target,
#   ]
# }

locals {
  pipeline_targets = [
    module.asg_dev.pipeline_target,
    module.asg_staging.pipeline_target,
    module.asg_prod.pipeline_target,
  ]
}

module "pipeline_kms_key" {
  source = "../modules/pipeline-kms-key"

  providers = {
    aws = aws.management
  }

  name    = "asg-pipeline"
  targets = local.pipeline_targets
}

module "ami_builds" {
  source = "../modules/s3-source"

  providers = {
    aws = aws.management
  }

  bucket_prefix = "asg-builds-"
  force_destroy = true
  key           = "ami.zip"
}

module "ami_pipeline" {
  source = "../modules/pipeline"

  providers = {
    aws = aws.management
  }

  name            = "asg-pipeline-ami"
  kms_key_arn     = module.pipeline_kms_key.arn
  targets         = local.pipeline_targets
  source_location = module.ami_builds.location
  type            = "ami"
}

module "app_builds" {
  source = "../modules/s3-source"

  providers = {
    aws = aws.management
  }

  bucket_prefix = "app-builds-"
  force_destroy = true
  key           = "app.zip"
}

module "app_pipeline" {
  source = "../modules/pipeline"

  providers = {
    aws = aws.management
  }

  name            = "asg-pipeline-app"
  kms_key_arn     = module.pipeline_kms_key.arn
  targets         = local.pipeline_targets
  source_location = module.app_builds.location
  type            = "app"
}
