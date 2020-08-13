output "ami_builds" {
  value = module.ami_builds
}

output "app_builds" {
  value = module.app_builds
}

# output "ami_builds" {
#   value = module.pipelines.ami_builds
# }

# output "app_builds" {
#   value = module.pipelines.app_builds
# }

output "urls" {
  value = {
    dev     = module.asg_dev.url
    staging = module.asg_staging.url
    prod    = module.asg_prod.url
  }
}
