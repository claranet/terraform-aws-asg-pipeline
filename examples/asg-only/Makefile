output = $(eval output := $$(shell terraform output -json))$(output)
get_output = $(shell echo '$(output)' | jq -r '.$(1)')

url = $(call get_output,url.value)

.PHONY: check
check:
	watch "echo '---\n\n$(url)\n' && curl -s $(url)"

.PHONY: vpc
vpc:
	env $$(awsp claranetuk-thirdplaygroundRW) aws ec2 create-default-vpc --region eu-west-1

