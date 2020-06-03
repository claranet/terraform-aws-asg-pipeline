from utils import codepipeline_lambda_handler, get_session, get_user_parameters, log


@codepipeline_lambda_handler
def lambda_handler(event, context):
    """
    Cleans up old versions from the app bucket.

    """

    # Get details from the event.
    job = event["CodePipeline.job"]
    user_params = get_user_parameters(job)
    app_bucket = user_params["AppLocation"]["Bucket"]
    app_key = user_params["AppLocation"]["Key"]
    assume_role_arn = user_params["AssumeRoleArn"]
    stack_name = user_params["StackName"]

    # Create clients in the target account.
    target_session = get_session(
        role_arn=assume_role_arn, session_name="cleanup-app-deployment"
    )
    target_cfn_client = target_session.client("cloudformation")
    target_s3_client = target_session.client("s3")

    # Delete any versions of the app that aren't being used.
    all_versions = set(
        get_all_s3_versions(s3_client=target_s3_client, bucket=app_bucket, key=app_key)
    )
    used_app_version = get_used_s3_version(
        cfn_client=target_cfn_client, stack_name=stack_name
    )
    for version in all_versions:
        if version != used_app_version:
            log("DELETE", version)
            target_s3_client.delete_object(
                Bucket=app_bucket, Key=app_key, VersionId=version
            )


def get_all_s3_versions(s3_client, bucket, key):
    """
    Returns all object versions in S3.

    """

    response = s3_client.list_object_versions(Bucket=bucket)
    for version in response.get("Versions", []):
        if version["Key"] == key:
            yield version["VersionId"]


def get_used_s3_version(cfn_client, stack_name):
    """
    Returns the object version used by the CloudFormation stack.

    """

    response = cfn_client.describe_stacks(StackName=stack_name)
    stack = response["Stacks"][0]
    outputs = {}
    for output in stack["Outputs"]:
        key = output["OutputKey"]
        value = output["OutputValue"]
        outputs[key] = value
    return outputs["AppVersionId"]
