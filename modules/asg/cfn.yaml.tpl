# Note that this file is a Terraform template which generates
# a CloudFormation YAML template. A dollar-brace will be rendered
# by Terraform. A dollar-dollar-brace is escaped by Terraform and
# ends up as a dollar-brace to be parsed by CloudFormation.

Parameters:
  AppVersionId:
    Type: AWS::SSM::Parameter::Value<String>
  AppVersionName:
    Type: AWS::SSM::Parameter::Value<String>
  ImageId:
    Type: AWS::SSM::Parameter::Value<String>
  ImageName:
    Type: AWS::SSM::Parameter::Value<String>

Resources:
  AutoScalingGroup:
    Type: AWS::AutoScaling::AutoScalingGroup
    Properties:
      AutoScalingGroupName: "${name}"
%{ if length(subnet_ids) == 0 ~}
      AvailabilityZones: !GetAZs ""
%{ endif ~}
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
      MinSize: ${min_size}
      MaxSize: ${max_size}
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
        MinInstancesInService: ${rolling_update_policy.MinInstancesInService}
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
        ImageId: !Ref ImageId
        InstanceType: "${instance_type}"
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
          - Key: AppVersionId
            Value: !Ref AppVersionId
          - Key: AppVersionName
            Value: !Ref AppVersionName
          - Key: ImageId
            Value: !Ref ImageId
          - Key: ImageName
            Value: !Ref ImageName
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

Outputs:
  AppVersionId:
    Value: !Ref AppVersionId
  AutoScalingGroupName:
    Value: !Ref AutoScalingGroup
