resource "random_string" "access_control" {
  length  = 32
  upper   = true
  lower   = true
  number  = true
  special = false
}
