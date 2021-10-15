variable "name" {
  description = "The name prefix for resources."
  type        = string
}

variable "app_version_id" {
  description = "Initial app version to use. Will be ignored after CodePipeline deploys a new version."
  default     = "dummy"
}

variable "app_version_name" {
  description = "Initial app version to use. Will be ignored after CodePipeline deploys a new version."
  default     = "dummy"
}

variable "detailed_monitoring" {
  description = "Specify true to enable detailed monitoring. Otherwise, basic monitoring is enabled."
  type        = bool
  default     = false
}

variable "health_check_grace_period" {
  description = "The amount of time, in seconds, that Amazon EC2 Auto Scaling waits before checking the health status of an EC2 instance that has come into service."
  type        = number
  default     = 0
}

variable "health_check_type" {
  description = "The service to use for the health checks. The valid values are EC2 (default) and ELB."
  type        = string
  default     = "EC2"
}

variable "image_id" {
  description = "Initial AMI to use. Will be ignored after CodePipeline deploys a new version."
  default     = "ami-00b5b04854bca6596"
}

variable "image_name" {
  description = "Initial AMI to use. Will be ignored after CodePipeline deploys a new version."
  default     = "dummy"
}

variable "instance_profile_arn" {
  description = "The IAM instance profile to use."
  type        = string
}

variable "instance_type" {
  description = "The type of instances to use."
  type        = string
}

variable "key_name" {
  description = "The EC2 key pair to use."
  type        = string
  default     = ""
}

variable "lifecycle_hooks" {
  description = "Lifecycle hook specifications. Use the format from: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-autoscaling-autoscalinggroup-lifecyclehookspecification.html"
  type        = list(map(any))
  default     = []
}

variable "max_size" {
  description = "The maximum size of the auto scaling group."
  type        = number
}

variable "min_size" {
  description = "The minimum size of the auto scaling group."
  type        = number
}

variable "pipeline_aws_account_id" {
  description = "The AWS account containing the pipeline."
  type        = string
}

variable "pipeline_auto_deploy" {
  description = "Whether the pipeline should automatically deploy to this auto scaling group (true) or wait for approval first (false)."
  type        = bool
}

variable "pipeline_target_name" {
  description = "The name to use in the pipeline to describe this auto scaling group, e.g. 'staging'."
  type        = string
}

variable "rolling_update_policy" {
  description = "Customise rolling update behaviour by setting any of MaxBatchSize, MinInstancesInService, MinSuccessfulInstancesPercent, PauseTime from https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-attribute-updatepolicy.html"
  type        = map(string)
  default     = {}
}

variable "security_group_ids" {
  description = "A list of security groups for the instances."
  type        = list(string)
  default     = []
}

variable "subnet_ids" {
  description = "A list of subnets to launch instances in."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "A map of tags to attach to the auto scale group and instances."
  type        = map(string)
  default     = {}
}

variable "propagate_tags_at_launch" {
  description = "Boolean to state whether ASG tags should be propagated to launched EC2s."
  type        = bool
  default     = false
}

variable "target_group_arns" {
  description = "A list of target groups, for use with load balancers."
  type        = list(string)
  default     = []
}

variable "user_data" {
  description = "User data to provide when launching the instance. This module will Base64 encode the provided string."
  type        = string
  default     = ""
}
