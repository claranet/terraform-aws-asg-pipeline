import json
import tempfile
import zipfile
from contextlib import contextmanager

from utils import (
    codepipeline_lambda_handler,
    create_zip_file,
    ec2_client,
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
    Prepares for an AMI deployment.

    """

    # Get details from the event.
    job = event["CodePipeline.job"]
    input_bucket, input_key = get_input_artifact_location(job)
    output_bucket, output_key = get_output_artifact_location(job)
    user_params = get_user_parameters(job)
    assume_role_arn = user_params["AssumeRoleArn"]
    parameter_names = user_params["ParameterNames"]
    stack_name = user_params["StackName"]
    template_filename = user_params["TemplateFilename"]

    # Create client in the pipeline account.
    pipeline_s3_client = get_artifact_s3_client(job)

    # Create clients in the target account.
    target_session = get_session(
        role_arn=assume_role_arn, session_name="prepare-ami-deployment"
    )
    target_cfn_client = target_session.client("cloudformation")
    target_ssm_client = target_session.client("ssm")

    # Download the input artifact zip file, read manifest.json from it,
    # and get the AMI it references. Also look up the associated image name.
    with download_zip_file(
        s3_client=pipeline_s3_client, bucket=input_bucket, key=input_key
    ) as zip_file:
        manifest_string = zip_file.read("manifest.json").decode("utf-8")
    log("MANIFEST", manifest_string)
    manifest = json.loads(manifest_string)
    image_id = manifest["builds"][-1]["artifact_id"].split(":")[1]
    log("IMAGE_ID", image_id)
    image_name = ec2_client.describe_images(ImageIds=[image_id])["Images"][0]["Name"]
    log("IMAGE_NAME", image_name)

    # Update the SSM parameters with the image details,
    # to be used by the CloudFormation deployment stage of the pipeline.
    target_ssm_client.put_parameter(
        Name=parameter_names["ImageId"], Value=image_id, Type="String", Overwrite=True
    )
    target_ssm_client.put_parameter(
        Name=parameter_names["ImageName"],
        Value=image_name,
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


@contextmanager
def download_zip_file(s3_client, bucket, key):
    """
    Downloads and extracts a zip file from S3.

    """

    temp_file = tempfile.NamedTemporaryFile()
    with tempfile.NamedTemporaryFile() as temp_file:
        s3_client.download_file(bucket, key, temp_file.name)
        with zipfile.ZipFile(temp_file.name, "r") as zip_file:
            yield zip_file
