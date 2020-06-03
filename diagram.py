from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import EC2
from diagrams.aws.devtools import Codebuild, Codepipeline
from diagrams.aws.management import AutoScaling, Cloudformation
from diagrams.aws.storage import S3
from diagrams.onprem.client import User
from diagrams.onprem.vcs import Github


def green(color="forestgreen", style="solid"):
    return Edge(color=color, style=style)


def red(color="firebrick", style="solid"):
    return Edge(color=color, style=style)


with Diagram("Auto Scaling Group Pipelines", filename="diagram", outformat="png"):

    github = Github("GitHub Actions\nApp Build")

    with Cluster("Management AWS Account"):

        builder = Codebuild("CodeBuild\nPacker AMI")

        with Cluster("S3-Source Module"):
            ami_s3 = S3("S3 Object\nami.zip")

        with Cluster(" S3-Source Module "): # use spaces to be different from the above cluster
            app_s3 = S3("S3 Object\napp.zip")

        builder >> ami_s3
        github >> app_s3

        with Cluster("Pipeline Module (type=ami)"):

            ami_pipeline_source = Codepipeline("S3 Source\nami.zip")
            ami_pipeline_dev = Codepipeline("Deploy to\nDev")
            ami_pipeline_approval_staging = User("Manual\nApproval")
            ami_pipeline_staging = Codepipeline("Deploy to\nStaging")
            ami_pipeline_approval_prod = User("Manual\nApproval")
            ami_pipeline_prod = Codepipeline("Deploy to\nProd")

            ami_s3 >> ami_pipeline_source >> ami_pipeline_dev >> ami_pipeline_approval_staging >> ami_pipeline_staging >> ami_pipeline_approval_prod >> ami_pipeline_prod

        with Cluster("Pipeline Module (type=app)"):

            app_pipeline_source = Codepipeline("S3 Source\napp.zip")
            app_pipeline_dev = Codepipeline("Deploy to\nDev")
            app_pipeline_approval_staging = User("Manual\nApproval")
            app_pipeline_staging = Codepipeline("Deploy to\nStaging")
            app_pipeline_approval_prod = User("Manual\nApproval")
            app_pipeline_prod = Codepipeline("Deploy to\nProd")

            app_s3 >> app_pipeline_source >> app_pipeline_dev >> app_pipeline_approval_staging >> app_pipeline_staging >> app_pipeline_approval_prod >> app_pipeline_prod

    with Cluster("Development AWS Account"):

        with Cluster("ASG Module"):

            cfn_dev = Cloudformation("CloudFormation\nStack")

            with Cluster("CloudFormation Resources"):
                asg_dev = AutoScaling("Auto Scaling\nGroup")
                ec2_dev = EC2("EC2 Instances")

            ami_pipeline_dev >> red() >> cfn_dev >> red() >> asg_dev >> red() >> ec2_dev
            app_pipeline_dev >> green() >> cfn_dev >> green() >> asg_dev >> green() >> ec2_dev

    with Cluster("Staging AWS Account"):

        with Cluster("ASG Module"):

            cfn_staging = Cloudformation("CloudFormation\nStack")

            with Cluster("CloudFormation Resources"):
                asg_staging = AutoScaling("Auto Scaling\nGroup")
                ec2_staging = EC2("EC2 Instances")

            ec2_staging << red() << asg_staging << red() << cfn_staging << red() << ami_pipeline_staging
            ec2_staging << green() << asg_staging << green() << cfn_staging << green() << app_pipeline_staging

    with Cluster("Production AWS Account"):

        with Cluster("ASG Module"):

            cfn_prod = Cloudformation("CloudFormation\nStack")

            with Cluster("CloudFormation Resources"):
                asg_prod = AutoScaling("Auto Scaling\nGroup")
                ec2_prod = EC2("EC2 Instances")

            app_pipeline_prod >> green() >> cfn_prod >> green() >> asg_prod >> green() >> ec2_prod
            ami_pipeline_prod >> red() >> cfn_prod >> red() >> asg_prod >> red() >> ec2_prod
