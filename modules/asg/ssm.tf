resource "aws_ssm_parameter" "app_version_id" {
  count = var.app_pipeline && var.enabled ? 1 : 0

  name  = "/${var.name}/app-version-id"
  type  = "String"
  value = "-"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "app_version_name" {
  count = var.app_pipeline && var.enabled ? 1 : 0

  name  = "/${var.name}/app-version-name"
  type  = "String"
  value = "-"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "image_id" {
  count = var.ami_pipeline && var.enabled ? 1 : 0

  name  = "/${var.name}/image-id"
  type  = "String"
  value = "-"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "image_name" {
  count = var.ami_pipeline && var.enabled ? 1 : 0

  name  = "/${var.name}/image-name"
  type  = "String"
  value = "-"

  lifecycle {
    ignore_changes = [value]
  }
}
