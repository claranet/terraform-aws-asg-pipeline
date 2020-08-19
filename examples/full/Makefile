date := $(shell date '+%F-%T')

output = $(eval output := $$(shell terraform output -json))$(output)
get_output = $(shell echo '$(output)' | jq -r '.$(1)')

ami_bucket = $(call get_output,ami_builds.value.location.bucket)
ami_key = $(call get_output,ami_builds.value.location.key)
ami_aws_access_key_id = $(call get_output,ami_builds.value.creds.aws_access_key_id)
ami_aws_secret_access_key = $(call get_output,ami_builds.value.creds.aws_secret_access_key)

app_bucket = $(call get_output,app_builds.value.location.bucket)
app_key = $(call get_output,app_builds.value.location.key)
app_aws_access_key_id = $(call get_output,app_builds.value.creds.aws_access_key_id)
app_aws_secret_access_key = $(call get_output,app_builds.value.creds.aws_secret_access_key)

url_dev = $(call get_output,urls.value.dev)
url_staging = $(call get_output,urls.value.staging)
url_prod = $(call get_output,urls.value.prod)

.PHONY: check
check:
	watch "echo '---\n\n$(url_dev)\n' && curl -s $(url_dev) && echo '\n---\n\n$(url_staging)\n' && curl -s $(url_staging) && echo '\n---\n\n$(url_prod)\n' && curl -s $(url_prod)"

.PHONY: clean
clean:
	rm -rf ami.zip app.zip index.html manifest.json

.PHONY: ami1
ami1:
	echo '{"builds": [{"artifact_id": "al2:ami-00b5b04854bca6596"}]}' > manifest.json
	zip ami.zip manifest.json
	AWS_ACCESS_KEY_ID=$(ami_aws_access_key_id) AWS_SECRET_ACCESS_KEY=$(ami_aws_secret_access_key) aws s3 cp ami.zip s3://$(ami_bucket)/$(ami_key) --metadata '{"codepipeline-artifact-revision-summary": "ami-00b5b04854bca6596 at $(date)"}'
	rm ami.zip manifest.json

.PHONY: ami2
ami2:
	echo '{"builds": [{"artifact_id": "ecs:ami-0a74b180a0c97ecd1"}]}' > manifest.json
	zip ami.zip manifest.json
	AWS_ACCESS_KEY_ID=$(ami_aws_access_key_id) AWS_SECRET_ACCESS_KEY=$(ami_aws_secret_access_key) aws s3 cp ami.zip s3://$(ami_bucket)/$(ami_key) --metadata '{"codepipeline-artifact-revision-summary": "ami-0a74b180a0c97ecd1 at $(date)"}'
	rm ami.zip manifest.json

.PHONY: app
app:
	echo "$(date)" > index.html
	zip app.zip index.html
	AWS_ACCESS_KEY_ID=$(app_aws_access_key_id) AWS_SECRET_ACCESS_KEY=$(app_aws_secret_access_key) aws s3 cp app.zip s3://$(app_bucket)/$(app_key) --metadata '{"codepipeline-artifact-revision-summary": "$(date)"}'
	rm app.zip index.html

vpc:
	env $$(awsp bashton-playgroundRW) aws ec2 create-default-vpc --region eu-west-1
	env $$(awsp bashton-secondplaygroundRW) aws ec2 create-default-vpc --region eu-west-1
