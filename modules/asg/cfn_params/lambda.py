import os

import boto3

import cfnresponse

autoscaling_client = boto3.client("autoscaling")
ssm_client = boto3.client("ssm")

AUTO_SCALING_GROUP_NAME = os.environ["AUTO_SCALING_GROUP_NAME"]
DEFAULT_AMI_SSM_PARAMETER = os.environ["DEFAULT_AMI_SSM_PARAMETER"]


def lambda_handler(event, context):
    status = cfnresponse.FAILED
    physical_resource_id = None
    response_data = {}

    try:

        # Check if CloudFormation is deleting the resource,
        # in which case it will be deleting the auto scaling group too,
        # so there's no need to launch instances.
        request_type = event["RequestType"]
        is_delete_operation = request_type == "Delete"

        # Check if this ASG has been created for use with AMI or app pipelines,
        # and either of those pipelines haven't been used yet. In that case,
        # it wouldn't make sense to launch instances yet.
        app_version_id = event["ResourceProperties"].get("AppVersionId")
        image_id = event["ResourceProperties"]["ImageId"]
        is_new_pipeline = app_version_id == "-" or image_id == "-"

        if is_new_pipeline or is_delete_operation:

            if is_new_pipeline:
                print("New pipeline, set to 0")

            if is_delete_operation:
                print("Delete operation, set to 0")

            min_size = 0
            max_size = 0
            min_instances_in_service = 0

            if image_id == "-":
                # Pick a valid AMI. It won't be used with the ASG
                # size set to 0 so it doesn't matter what it is.
                image_id = get_ami(DEFAULT_AMI_SSM_PARAMETER)

        else:

            min_size = int(event["ResourceProperties"]["MinSize"])
            max_size = int(event["ResourceProperties"]["MaxSize"])

            min_instances_in_service = int(event["ResourceProperties"]["MinInstancesInService"])
            if min_instances_in_service < 0:

                # CloudFormation tries to keep a specified number of instances
                # in-service while replacing instances. Try to use the current
                # number of running instances.
                min_instances_in_service = get_desired_capacity(AUTO_SCALING_GROUP_NAME)
                print(f"Using desired capacity for MinInstancesInService={min_instances_in_service}")

                # Unless it's below the minimum size of the ASG,
                # in which case try to use that.
                if min_instances_in_service < min_size:
                    min_instances_in_service = min_size
                    print(f"Desired capacity too low, set MinInstancesInService={min_instances_in_service}")

                # The number can't be the maximum size of the ASG because
                # it needs to be allowed to terminate instances (bringing
                # the number of in-service instance down) to replace them.
                if min_instances_in_service >= max_size:
                    if max_size > 1:
                        min_instances_in_service = max_size - 1
                    else:
                        min_instances_in_service = 0
                    print(f"Desired capacity too high, set MinInstancesInService={min_instances_in_service}")

        response_data = {
            "ImageId": image_id,
            "MinSize": min_size,
            "MaxSize": max_size,
            "MinInstancesInService": min_instances_in_service,
        }

        status = cfnresponse.SUCCESS

    finally:
        cfnresponse.send(event, context, status, response_data, physical_resource_id)


def get_ami(ssm_parameter_name):
    """
    Looks up an AMI from the SSM parameter store.
    """

    response = ssm_client.get_parameter(Name=ssm_parameter_name)
    return response["Parameter"]["Value"]


def get_desired_capacity(auto_scaling_group_name):
    """
    Returns the current desired capacity of the ASG,
    or zero if it doesn't exist.

    """

    response = autoscaling_client.describe_auto_scaling_groups(
        AutoScalingGroupNames=[auto_scaling_group_name],
    )
    for asg in response["AutoScalingGroups"]:
        return asg["DesiredCapacity"]
    return 0
