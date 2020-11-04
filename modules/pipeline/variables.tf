variable "name" {
  description = "The pipeline name."
  type        = string
}

variable "kms_key_arn" {
  description = "The KMS key to use for artifacts."
  type        = string
}

variable "source_location" {
  description = "The pipeline S3 source location. The pipeline will start when a file is uploaded here."
  type        = object({ bucket = string, key = string })
}

variable "targets" {
  description = "A list of targets to deploy to. This should be a list of 'pipeline_target' outputs from uses of the 'asg' module."
  type = list(object({
    app_location = object({
      bucket = string
      key    = string
    })
    assume_role = object({
      arn = string
    })
    auto_deploy = bool
    cfn_role = object({
      arn = string
    })
    cfn_stack = object({
      arn    = string
      name   = string
      params = map(string)
    })
    name = string
    ssm_params = object({
      app_version_id = object({
        arn  = string
        name = string
      })
      app_version_name = object({
        arn  = string
        name = string
      })
      image_id = object({
        arn  = string
        name = string
      })
      image_name = object({
        arn  = string
        name = string
      })
    })
  }))
}

variable "type" {
  description = "The type of pipeline to create, either 'ami' or 'app'."
  type        = string
}
