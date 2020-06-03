resource "aws_ssm_parameter" "app_version_id" {
  name  = "/${var.name}/app-version-id"
  type  = "String"
  value = var.app_version_id

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "app_version_name" {
  name  = "/${var.name}/app-version-name"
  type  = "String"
  value = var.app_version_name

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "image_id" {
  name  = "/${var.name}/image-id"
  type  = "String"
  value = var.image_id

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "image_name" {
  name  = "/${var.name}/image-name"
  type  = "String"
  value = var.image_name

  lifecycle {
    ignore_changes = [value]
  }
}
