pipeline_aws_profile = REDACTED
target_aws_profile = REDACTED
ami_builds_bucket = REDACTED
app_builds_bucket = REDACTED

date = $(shell date '+%F-%T')

al2_ami = ami-00b5b04854bca6596
ecs_ami = ami-0a74b180a0c97ecd1

clean:
	rm -f manifest.json ami.zip app.txt app.zip

al2:
	make upload_ami NAME=$@-$(date) AMI=$(al2_ami)

ecs:
	make upload_ami NAME=$@-$(date) AMI=$(ecs_ami)

upload_ami: clean
	echo '{"builds": [{"artifact_id": "al2:$(AMI)"}]}' > manifest.json
	zip ami.zip manifest.json
	env $$(awsp $(pipeline_aws_profile)) aws s3 cp ami.zip s3://$(ami_builds_bucket)/ami.zip --metadata '{"codepipeline-artifact-revision-summary": "$(NAME)"}'
	make clean

app: clean
	echo $(date) > app.txt
	zip app.zip app.txt
	env $$(awsp $(pipeline_aws_profile)) aws s3 cp app.zip s3://$(app_builds_bucket)/app.zip --metadata '{"codepipeline-artifact-revision-summary": "app-$(date)"}'
	make clean

reset:
	find -maxdepth 3 -type d -name .terraform -exec rm -rf {} \;

vpc:
	env $$(awsp $(target_aws_profile)) aws ec2 create-default-vpc --region eu-west-1
