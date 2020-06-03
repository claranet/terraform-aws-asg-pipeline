from utils import (
    codepipeline_lambda_handler,
    create_zip_file,
    get_artifact_s3_client,
    get_cloudformation_template,
    get_input_artifact_location,
    get_output_artifact_location,
    get_session,
    get_user_parameters,
    log,
)


@codepipeline_lambda_handler
def lambda_handler(event, context):
    """
    Prepares for an app deployment.

    """

    # Get details from the event.
    job = event["CodePipeline.job"]
    input_bucket, input_key = get_input_artifact_location(job)
    output_bucket, output_key = get_output_artifact_location(job)
    user_params = get_user_parameters(job)
    app_bucket = user_params["AppLocation"]["Bucket"]
    app_key = user_params["AppLocation"]["Key"]
    assume_role_arn = user_params["AssumeRoleArn"]
    parameter_names = user_params["ParameterNames"]
    stack_name = user_params["StackName"]
    template_filename = user_params["TemplateFilename"]

    # Create client in the pipeline account.
    pipeline_s3_client = get_artifact_s3_client(job)

    # Create clients in the target account.
    target_session = get_session(
        role_arn=assume_role_arn, session_name="prepare-app-deployment"
    )
    target_cfn_client = target_session.client("cloudformation")
    target_ssm_client = target_session.client("ssm")
    target_s3_client = target_session.client("s3")

    # Get the friendly name from the input artifact metadata,
    # to be added to EC2 tags for visibility.
    response = pipeline_s3_client.head_object(Bucket=input_bucket, Key=input_key)
    app_version_name = response["Metadata"].get(
        "codepipeline-artifact-revision-summary", "-"
    )
    log("APP_VERSION_NAME", app_version_name)

    # Copy the input artifact to the environment's app bucket,
    # to be used by EC2 instances when they boot up.
    response = target_s3_client.copy_object(
        CopySource={"Bucket": input_bucket, "Key": input_key},
        Bucket=app_bucket,
        Key=app_key,
    )
    app_version_id = response["VersionId"]
    log("APP_VERSION_ID", app_version_id)

    # Update the SSM parameters with the app version details,
    # to be used by the CloudFormation deployment stage of the pipeline.
    target_ssm_client.put_parameter(
        Name=parameter_names["AppVersionId"],
        Value=app_version_id,
        Type="String",
        Overwrite=True,
    )
    target_ssm_client.put_parameter(
        Name=parameter_names["AppVersionName"],
        Value=app_version_name,
        Type="String",
        Overwrite=True,
    )

    # Write the CloudFormation stack's template to the output artifact location,
    # to be used by the CloudFormation deployment stage of the pipeline.
    template = get_cloudformation_template(
        cfn_client=target_cfn_client, stack_name=stack_name
    )
    with create_zip_file({template_filename: template}) as zip_path:
        pipeline_s3_client.upload_file(zip_path, output_bucket, output_key)
