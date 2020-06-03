# Get the pipeline targets, i.e. where the pipelines will deploy to.

data "terraform_remote_state" "app_dev" {
  backend = "s3"
  config = {
    bucket  = "${var.project_name}-REDACTED-tfstate"
    key     = "app-dev/terraform.tfstate"
    region  = "eu-west-1"
    encrypt = true
  }
}

data "terraform_remote_state" "app_staging" {
  backend = "s3"
  config = {
    bucket  = "${var.project_name}-REDACTED-tfstate"
    key     = "app-staging/terraform.tfstate"
    region  = "eu-west-1"
    encrypt = true
  }
}

data "terraform_remote_state" "app_prod" {
  backend = "s3"
  config = {
    bucket  = "${var.project_name}-REDACTED-tfstate"
    key     = "app-prod/terraform.tfstate"
    region  = "eu-west-1"
    encrypt = true
  }
}

locals {
  pipeline_targets = [
    data.terraform_remote_state.app_dev.outputs.pipeline_target,
    data.terraform_remote_state.app_staging.outputs.pipeline_target,
    data.terraform_remote_state.app_prod.outputs.pipeline_target,
  ]
}

# Create a KMS key for pipeline artifacts.

module "pipeline_kms_key" {
  source = "./modules/pipeline-kms-key"

  name    = var.project_name
  targets = local.pipeline_targets
}

# Create a pipeline to deploy new AMIs.
# The AMI build process must upload new Packer manifests to this bucket.
# TODO: use s3-source module to create bucket

resource "aws_s3_bucket" "ami_builds" {
  bucket = "${var.project_name}-ami-builds"
  acl    = "private"

  versioning {
    enabled = true
  }
}

module "ami_pipeline" {
  source = "./modules/pipeline"

  name            = "${var.project_name}-ami"
  kms_key_arn     = module.pipeline_kms_key.arn
  targets         = local.pipeline_targets
  source_location = { bucket = aws_s3_bucket.ami_builds.bucket, key = "ami.zip" }
  type            = "ami"
}

# Create a pipeline to deploy new app builds.
# The app build process must upload new app builds to this bucket.
# TODO: use s3-source module

resource "aws_s3_bucket" "app_builds" {
  bucket = "${var.project_name}-app-builds"
  acl    = "private"

  versioning {
    enabled = true
  }
}

module "app_pipeline" {
  source = "./modules/pipeline"

  name            = "${var.project_name}-app"
  kms_key_arn     = module.pipeline_kms_key.arn
  targets         = local.pipeline_targets
  source_location = { bucket = aws_s3_bucket.app_builds.bucket, key = "app.zip" }
  type            = "app"
}
