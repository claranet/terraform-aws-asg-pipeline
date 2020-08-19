# terraform-aws-asg-codepipeline

This module is used to create Auto Scaling Groups and CodePipeline pipelines for deploying changes to them. This can be used to create a pipeline for deploying AMIs, or application artifacts, or both.

## Overview

* Auto Scaling Groups are created using CloudFormation with a [rolling update policy](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-attribute-updatepolicy.html#cfn-attributes-updatepolicy-rollingupdate).
* EC2 instances in the Auto Scaling Groups are replaced during deployments.
* Rolling updates wait for target group health checks before terminating old instances, using a Lambda function and [CloudFormation Resource Signals](https://docs.aws.amazon.com/AWSCloudFormation/latest/APIReference/API_SignalResource.html)
* Optional approval step per environment (e.g. automatically deploy to dev, but wait for approval before deploying production).
* Supports cross-account pipelines.

The following diagram shows how we have used this module to handle both AMI and application deployments to Auto Scaling Groups in multiple environments. Deployments always roll out to the development environment straight away, but require approval before being promoted to the staging and production environments.

![Diagram](diagram.png?raw=true)

## ASG module

The `asg` module creates an Auto Scaling Group using CloudFormation. Don't worry, it's still managed by Terraform  in the same way as other AWS resources. CodePipeline natively supports performing CloudFormation stack updates, so this is the ideal way to manage the Auto Scaling Group and its related resources.

You must set `ami_pipeline = true` and/or `app_pipeline = true` when using this module, if you intend to create deployment pipelines. This module can still be used to create and manage auto scaling groups without pipelines, and still have the benefits of CloudFormation's rolling updates when changing properties such as `image_id`, `instance_type`, and `user_data`.

This module outputs a `pipeline_target` value to be passed into the `pipeline` module.

## S3 source module

The `s3-source` module creates an S3 bucket and an IAM user which has permission to upload files to that bucket.

This module outputs a `location` value to be passed into the `pipeline` module. It also outputs a `creds` value containing AWS credentials, to be used by external build systems to upload deployable artifacts.

Using this module is optional. It is just a quick and easy way to create a bucket and credentials.

## Pipeline module (type=ami)

When using the `pipeline` module with `type=ami`, the pipeline will read a zip file expecting to find a [Packer](https://www.packer.io/) manifest JSON file. This manifest should contain an image ID created by Packer.

The pipeline will update the ASG CloudFormation stacks to use the AMI. EC2 instances in the Auto Scaling Group will be replaced with new instances using the new AMI.

This module currently only supports Packer manifests with specific filenames. We are interested in adding support for [EC2 Image Builder](https://aws.amazon.com/image-builder/) in the future, and making the Packer support more flexible.

### Instructions

Add this to your Packer template to create the manifest JSON file:

```json
  "post-processors": [
    {
      "type": "manifest",
      "output": "manifest.json"
    }
  ]
```

If using CodeBuild to run Packer, the following can be added to your buildspec file to zip the manifest file and upload it to S3.

```
  post_build:
    commands:
      - echo "Uploading manifest to pipeline source bucket"
      - zip ami.zip manifest.json
      - export AMI=$(jq -r .builds[0].artifact_id manifest.json | cut -d ":" -f 2)
      - 'aws s3 cp ami.zip s3://$ARTIFACT_BUCKET/$ARTIFACT_KEY --metadata "{\"codepipeline-artifact-revision-summary\": \"$AMI\"}"'
```

This relies on `ARTIFACT_BUCKET` and `ARTIFACT_KEY` environment variables being provided, and `jq` being available in the CodeBuild image.

The `--metadata` value makes the image ID visible in the CodePipeline console, making it easier to see which image is being deployed.

## Pipeline module (type=app)

When using the `pipeline` module with `type=app`, the pipeline will copy a source zip file into an S3 bucket for each Auto Scaling Group. This zip file can contain anything you want, for example the source code for a website.

The pipeline will update the ASG CloudFormation stacks and set EC2 tags with new location of the zip file (a versioned S3 object). EC2 instances in the Auto Scaling Group will be replaced, so instances will need to download and make use of the new zip file when booting up.

### Instructions

The following boot script demonstrates how to download and extract the app artifact:

```
instance_id=$(curl -sS http://169.254.169.254/latest/meta-data/instance-id)
region=$(curl -sS http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//')
app_version=$(aws ec2 describe-tags --region $region --filters \"Name=resource-id,Values=$instance_id\" --query \"Tags[?Key=='AppVersion'].Value\" --output text)
aws s3api get-object --bucket ${module.asg.app_location.bucket} --key ${module.asg.app_location.key} --version-id $app_version /tmp/app.zip
unzip /tmp/app.zip
```

## Putting it all together

1. Use the `asg` module in one or more environments.
    * If using an app pipeline, ensure the ASG has a boot script that will download and make use of the app artifacts that the pipeline moves into place during deployments.
2. Use the `s3-source` module to create an S3 bucket, with IAM credentials, which will be used to trigger a pipeline when files are uploaded.
2. Use the `pipeline` module to create pipeline(s).
    * Pass in the `location` output from the `s3-source` module.
    * Pass in the `pipeline_target` output from anywhere you used the `asg` module.
    * Specify `type=ami` or `type=app` depending on the type of pipeline to create.
3. Upload a zipped Packer manifest file to S3 to trigger AMI pipelines.
4. Upload a zipped application artifact to S3 to trigger app pipelines.

## Caveats

### Simultaneous deployments conflict

When using 2 pipelines (AMI and app), and they both attempt to update the same ASG at the same time, one of them will fail. You can just wait until the other pipeline has finished and then click the `retry` button on the one that failed.

### CodePipeline is what it is

This uses CodePipeline, which comes with some limitations and quirks:

* The pipeline is linear, going from one environment to the next. You cannot choose to deploy to a specific environment; you must promote it all the way through the predefined pipeline.
* It is confusing when there are multiple pipeline executions running at the same time. The CodePipeline console can be deceptive, for example making it look like you are approving the version currently running in staging into production, but you may actually be approving the previous version. Make sure to check the `Pipeline execution ID` and `Source` when approving deployments.

### Imperfect ELB health checks

If you deploy to an ASG when an instance has recently been launched and it is EC2-healthy/ELB-unhealthy (e.g. it's still provisioning), CloudFormation can consider it as healthy and immediately terminate an older, ELB-healthy instance. This results in an increased traffic share and therefore increased load on any remaining ELB-healthy instances, or a complete outage if the terminated instance was the only ELB-healthy instance. This occurs because CloudFormation only looks at EC2 health, not ELB health, when performing rolling updates, so it thinks the new EC2-healthy/ELB-unhealthy instance is "healthy".

[This article](https://daniellanger.com/zero-downtime-deploys-with-cloudformation/) explains some of the background of this problem but the solutions offered don't help with this specific issue.

Affected systems:

* Small auto scaling groups.
* This issue can only occur immediately after an instance has launched into the auto scaling group (e.g. auto scaled or manually changed the desired count) and lasts until the new instance is provisioned and serving traffic (i.e. the time it takes to provision an instance).

Steps to reproduce:

1. Start with ASG desired=1, min=1, max=2.
    * 1 instance in ASG and it is EC2-healthy.
    * 1 instance in Target Group and it is ELB-healthy.
2. Change ASG to desired=2.
3. Wait until the instance has launched but isn't yet ELB-healthy.
3. Start CFN deployment to the ASG.
4. CFN will launch a new instance and terminate the old instance.
5. Target group healthy instances becomes zero and there is a service outage.

Remediation:

* Use a lifecycle hook to prevent instances from going in-service immediately after launching.
* At the end of the boot script, if everything was successful, complete the lifecycle hook.
* If possible, first perform the same/similar health check as the ELB health check (e.g. make a request to the health check URL and verify the response status code) to reduce the chances of the instance going in-service/EC2-healthy but not becoming ELB-healthy. This won't be 100% reliable because you can't test the exact network path used by the ELB from the instance.
* The instance will become in-service/EC2-healthy, then the load balancer will start checking its health, and then soon afterwards it will become ELB-healthy.
* There is still a small window of time where the instance is EC2-healthy and ELB-unhealthy for this issue to occur. This window of time will be based on the Target Group health check interval and healthy threshold.
* This is a big improvement for instances that take a long time to provision, but it is not perfect.

## Playbooks

### CloudFormation waiting on resource signals

If instances are not launching properly then it could leave CloudFormation stuck waiting for resource signals, with a message like this:

```
Waiting on 1 resource signal(s) with a timeout of PT1H
```

You should be able to wait for it to time out. However, if you don't want to wait then you can manually send the signal like this:

```
aws cloudformation signal-resource --status SUCCESS --logical-resource-id AutoScalingGroup --stack-name $STACK_NAME --unique-id $INSTANCE_ID
```

This is normally not be required, and should be used with caution in live systems. It is dangerous because it tells CloudFormation to proceed with a rolling update ignoring the state of the instance. This could result in an outage.
