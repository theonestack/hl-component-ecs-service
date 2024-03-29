CfhighlanderTemplate do

  if ((defined? network_mode) && (network_mode == "awsvpc"))
    if ((defined? securityGroups) && (securityGroups.has_key?(component_name)))
      DependsOn 'vpc'
    elsif ((defined? security_group_rules) && security_group_rules.any?)
      DependsOn 'lib-ec2'
    end
  end

  DependsOn 'lib-iam'
  DependsOn 'lib-alb'

  Description "ecs-service - #{component_name} - #{component_version}"

  Parameters do
    ComponentParam 'EnvironmentName', 'dev', isGlobal: true
    ComponentParam 'EnvironmentType', 'development', allowedValues: ['development','production'], isGlobal: true
    ComponentParam 'EcsCluster'
    ComponentParam 'UserPoolId', ''
    ComponentParam 'UserPoolClientId', ''
    ComponentParam 'UserPoolDomainName', ''

    if (defined? targetgroup) || ((defined? network_mode) && (network_mode == "awsvpc"))
      ComponentParam 'VPCId', type: 'AWS::EC2::VPC::Id'
    end

    if defined? targetgroup
      ComponentParam 'DnsDomain'

      if targetgroup.is_a?(Array)
        targetgroup.each do |tg|
          if tg.has_key?('rules')
            ComponentParam "#{tg['listener']}Listener"
          else
            ComponentParam "#{tg['name'].gsub(/[^0-9A-Za-z]/, '')}TargetGroup"
          end
        end
      else
        ComponentParam 'TargetGroup'
        ComponentParam 'Listener'
        ComponentParam 'LoadBalancer'
      end
    end

    ComponentParam 'DesiredCount', 1
    ComponentParam 'MinimumHealthyPercent', 100
    ComponentParam 'MaximumPercent', 200

    ComponentParam 'EnableScaling', 'false', allowedValues: ['true','false']

    if ((defined? network_mode) && (network_mode == "awsvpc"))
      ComponentParam 'SubnetIds', type: 'CommaDelimitedList'
      ComponentParam 'SecurityGroupBackplane'
      ComponentParam 'EnableFargate', 'false'
      ComponentParam 'DisableLaunchType', 'false'
      ComponentParam 'PlatformVersion', platform_version if defined? platform_version
    end

    task_definition.each do |task_def, task|
      if task.has_key?('tag_param')
        default_value = task.has_key?('tag_param_default') ? task['tag_param_default'] : 'latest'
        ComponentParam task['tag_param'], default_value
      end
    end if defined? task_definition

    ComponentParam 'NamespaceId' if defined? service_discovery

  end

end
