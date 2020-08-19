variable "name" {
  type = string
}

variable "pipeline_auto_deploy" {
  type = bool
}

variable "pipeline_aws_account_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}
