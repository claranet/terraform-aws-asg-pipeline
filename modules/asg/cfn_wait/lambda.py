import time

import boto3

import cfnresponse

autoscaling_client = boto3.client("autoscaling")


def lambda_handler(event, context):
    """
    Look up and wait for any instances in the Terminating:Wait state.
    It is assumed that any instances in this state need to do something
    important before they can be terminated, so CloudFormation should wait
    for that to happen as part of the stack update.

    Such instances might be ECS or Kubernetes nodes with a lifecycle hook
    that drains tasks before being terminated. Those tasks would be scheduled
    on the new instances that were launched as part of the rolling update. The
    auto scaling group isn't really stable until those tasks have been moved,
    so the CloudFormation stack uses this function to wait during stack updates.

    This function will wait as long as it finds instances in the
    Terminating:Wait state. The function may even time out while waiting.
    If that happens, the function will be retried a few times and then it
    will give up. If that happens then CloudFormation will roll back the
    stack update.

    """

    status = cfnresponse.FAILED
    physical_resource_id = None
    response_data = {}

    try:

        asg_arn = ""
        asg_name = event["ResourceProperties"]["AutoScalingGroupName"]

        while True:
            wait = False
            response = autoscaling_client.describe_auto_scaling_groups(
                AutoScalingGroupNames=[asg_name],
            )
            for asg in response["AutoScalingGroups"]:
                asg_arn = asg["AutoScalingGroupARN"]
                for instance in asg["Instances"]:
                    if instance["LifecycleState"] == "Terminating:Wait":
                        wait = True
                        instance_id = instance["InstanceId"]
                        print(f"Waiting for {instance_id} terminate lifecycle action")
            if wait:
                time.sleep(30)
            else:
                break

        response_data["AutoScalingGroupARN"] = asg_arn
        status = cfnresponse.SUCCESS

    finally:
        cfnresponse.send(event, context, status, response_data, physical_resource_id)
