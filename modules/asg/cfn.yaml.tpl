# Note that this file is a Terraform template which generates
# a CloudFormation YAML template. A dollar-brace will be rendered
# by Terraform. A dollar-dollar-brace is escaped by Terraform and
# ends up as a dollar-brace to be parsed by CloudFormation.

Parameters:
%{ if app_pipeline ~}
  AppVersionId:
    Type: AWS::SSM::Parameter::Value<String>
  AppVersionName:
    Type: AWS::SSM::Parameter::Value<String>
%{ endif ~}
%{ if ami_pipeline ~}
  ImageId:
    Type: AWS::SSM::Parameter::Value<String>
  ImageName:
    Type: AWS::SSM::Parameter::Value<String>
%{ else ~}
  ImageId:
    Type: String
%{ endif ~}
  TemplateHash:
    Type: String

Resources:

  Params:
    Type: Custom::Params
    Properties:
%{ if app_pipeline ~}
      AppVersionId: !Ref AppVersionId
%{ endif ~}
      ImageId: !Ref ImageId
      MaxSize: ${max_size}
      MinInstancesInService: ${rolling_update_policy.MinInstancesInService}
      MinSize: ${min_size}
      ServiceToken: ${cfn_params_lambda_arn}

  AutoScalingGroup:
    Type: AWS::AutoScaling::AutoScalingGroup
    Properties:
      AutoScalingGroupName: "${name}"
%{ if length(subnet_ids) == 0 ~}
      AvailabilityZones: !GetAZs ""
%{ endif ~}
      HealthCheckGracePeriod: ${health_check_grace_period}
      HealthCheckType: "${health_check_type}"
      LaunchTemplate:
        LaunchTemplateId: !Ref LaunchTemplate
        Version: !GetAtt LaunchTemplate.LatestVersionNumber
%{ if length(lifecycle_hooks) > 0 ~}
      LifecycleHookSpecificationList: ${jsonencode(lifecycle_hooks)}
%{ endif ~}
      MetricsCollection:
      - Granularity: 1Minute
        Metrics:
        - GroupMinSize
        - GroupMaxSize
        - GroupDesiredCapacity
        - GroupInServiceInstances
        - GroupPendingInstances
        - GroupStandbyInstances
        - GroupTerminatingInstances
        - GroupTotalInstances
        - GroupInServiceCapacity
        - GroupPendingCapacity
        - GroupStandbyCapacity
        - GroupTerminatingCapacity
        - GroupTotalCapacity
      MinSize: !GetAtt Params.MinSize
      MaxSize: !GetAtt Params.MaxSize
      Tags:
      - Key: AccessControl
        Value: "${access_control}"
        PropagateAtLaunch: false
%{ for key, value in tags ~}
      - Key: "${key}"
        Value: "${value}"
        PropagateAtLaunch: false
%{ endfor ~}
      TargetGroupARNs: ${jsonencode(target_group_arns)}
%{ if length(subnet_ids) > 0 ~}
      VPCZoneIdentifier: ${jsonencode(subnet_ids)}
%{ endif ~}
    UpdatePolicy:
      AutoScalingRollingUpdate:
        MaxBatchSize: ${rolling_update_policy.MaxBatchSize}
        MinInstancesInService: !GetAtt Params.MinInstancesInService
        MinSuccessfulInstancesPercent: ${rolling_update_policy.MinSuccessfulInstancesPercent}
        PauseTime: ${rolling_update_policy.PauseTime}
        SuspendProcesses:
        - HealthCheck
        - ReplaceUnhealthy
        - AZRebalance
        - AlarmNotification
        - ScheduledActions
        WaitOnResourceSignals: true

  LaunchTemplate:
    Type: AWS::EC2::LaunchTemplate
    Properties:
      LaunchTemplateData:
        IamInstanceProfile:
          Arn: "${instance_profile_arn}"
        ImageId: !GetAtt Params.ImageId
        InstanceType: "${instance_type}"
%{ if length(block_device_mappings) > 0 ~}
        BlockDeviceMappings: ${jsonencode(block_device_mappings)}
%{ endif ~}
%{ if key_name != "" ~}
        KeyName: "${key_name}"
%{ endif ~}
        Monitoring:
          Enabled: ${jsonencode(detailed_monitoring)}
%{ if length(security_group_ids) > 0 ~}
        SecurityGroupIds: ${jsonencode(security_group_ids)}
%{ endif ~}
        TagSpecifications:
        - ResourceType: instance
          Tags:
          - Key: AccessControl
            Value: "${access_control}"
%{ if app_pipeline ~}
          - Key: AppVersionId
            Value: !Ref AppVersionId
          - Key: AppVersionName
            Value: !Ref AppVersionName
%{ endif ~}
          - Key: ImageId
            Value: !Ref ImageId
%{ if ami_pipeline ~}
          - Key: ImageName
            Value: !Ref ImageName
%{ endif ~}
          - Key: Name
            Value: "${name}"
%{ for key, value in tags ~}
          - Key: "${key}"
            Value: "${value}"
%{ endfor ~}
%{ if user_data != "" ~}
        UserData: ${base64encode(user_data)}
%{ endif ~}
      LaunchTemplateName: "${name}"

  Wait:
    Type: Custom::Wait
    DependsOn:
    - AutoScalingGroup
    - LaunchTemplate
    Properties:
%{ if app_pipeline ~}
      AppVersionId: !Ref AppVersionId
      AppVersionName: !Ref AppVersionName
%{ endif ~}
      AutoScalingGroupName: !Ref AutoScalingGroup
      ImageId: !Ref ImageId
%{ if ami_pipeline ~}
      ImageName: !Ref ImageName
%{ endif ~}
      LaunchTemplate: !Ref LaunchTemplate
      ServiceToken: ${cfn_wait_lambda_arn}
      TemplateHash: !Ref TemplateHash

Outputs:
%{ if app_pipeline ~}
  AppVersionId:
    Value: !Ref AppVersionId
%{ endif ~}
  AutoScalingGroupARN:
    Value: !GetAtt Wait.AutoScalingGroupARN
  AutoScalingGroupName:
    Value: !Ref AutoScalingGroup
