import json
import os

import boto3

LOGICAL_RESOURCE_ID = os.environ["LOGICAL_RESOURCE_ID"]
STACK_NAME = os.environ["STACK_NAME"]
TARGET_GROUP_ARNS = json.loads(os.environ["TARGET_GROUP_ARNS"])

cfn_client = boto3.client("cloudformation")
elb_client = boto3.client("elbv2")
target_in_service = elb_client.get_waiter("target_in_service")


def lambda_handler(event, context):
    # An instance has been launched.
    # Get the details from the event.
    instance_id = event["detail"]["EC2InstanceId"]
    print(f"InstanceId={instance_id} Instance has launched")

    # Fetch the target group details and loop over them.
    response = elb_client.describe_target_groups(TargetGroupArns=TARGET_GROUP_ARNS)
    for target_group in response["TargetGroups"]:

        # Wait until the target group thinks the instance is healthy.
        # Wait for so long that the Lambda function will time out before
        # this ever does. If it times out, the function will be retried
        # a few times and then give up. If this fails during a CloudFormation
        # update then CloudFormation will roll back the update.
        print(
            f"InstanceId={instance_id} Waiting until instance is healthy in {target_group['TargetGroupArn']}"
        )
        target_in_service.wait(
            TargetGroupArn=target_group["TargetGroupArn"],
            Targets=[{"Id": instance_id, "Port": target_group["Port"]}],
            WaiterConfig={"Delay": 30, "MaxAttempts": 1000},
        )
        print(
            f"InstanceId={instance_id} Instance is healthy in {target_group['TargetGroupArn']}"
        )

    # Tell CloudFormation that this instance is ready.
    print(f"InstanceId={instance_id} Sending signal to CloudFormation")
    cfn_client.signal_resource(
        StackName=STACK_NAME,
        LogicalResourceId=LOGICAL_RESOURCE_ID,
        UniqueId=instance_id,
        Status="SUCCESS",
    )
