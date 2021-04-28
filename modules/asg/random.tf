resource "random_string" "access_control" {
  count   = var.enabled ? 1 : 0
  length  = 32
  upper   = true
  lower   = true
  number  = true
  special = false
}
