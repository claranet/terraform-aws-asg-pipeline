module "kms_key" {
  source = "../../../modules/pipeline-kms-key"

  name    = var.name
  targets = var.targets
}

module "ami_builds" {
  source = "../../../modules/s3-source"

  bucket_prefix = "${var.name}-ami-builds-"
  key           = "ami.zip"
}

module "ami_pipeline" {
  source = "../../../modules/pipeline"

  name            = "${var.name}-ami"
  kms_key_arn     = module.kms_key.arn
  targets         = var.targets
  source_location = module.ami_builds.location
  type            = "ami"
}

module "app_builds" {
  source = "../../../modules/s3-source"

  bucket_prefix = "${var.name}-app-builds-"
  key           = "app.zip"
}

module "app_pipeline" {
  source = "../../../modules/pipeline"

  name            = "${var.name}-app"
  kms_key_arn     = module.kms_key.arn
  targets         = var.targets
  source_location = module.app_builds.location
  type            = "app"
}
