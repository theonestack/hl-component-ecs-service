CloudFormation do

  export = external_parameters.fetch(:export_name, external_parameters[:component_name])

  awsvpc_enabled = false
  network_mode = external_parameters.fetch(:network_mode, '')
  if network_mode == 'awsvpc'
    awsvpc_enabled = true
    Condition('IsFargate', FnEquals(Ref('EnableFargate'), 'true'))
    Condition('IsEmptyLaunchType', FnEquals(Ref('DisableLaunchType'), 'true'))
  end

  tags = []
  tags << { Key: "Name", Value: external_parameters[:component_name] }
  tags << { Key: "Environment", Value: Ref("EnvironmentName") }
  tags << { Key: "EnvironmentType", Value: Ref("EnvironmentType") }

  Condition('IsScalingEnabled', FnEquals(Ref('EnableScaling'), 'true'))

  log_retention = external_parameters.fetch(:log_retention, 7)

  Logs_LogGroup('LogGroup') {
    LogGroupName Ref('AWS::StackName')
    RetentionInDays "#{log_retention}"
  }

  definitions, task_volumes, secrets = Array.new(3){[]}
  secrets_policy = {}

  task_definition = external_parameters.fetch(:task_definition, {})
  task_definition.each do |task_name, task|

    env_vars, mount_points, ports, volumes_from, port_mappings = Array.new(5){[]}
    
    name = task.has_key?('name') ? task['name'] : task_name

    image_repo = task.has_key?('repo') ? "#{task['repo']}/" : ''
    image_name = task.has_key?('image') ? task['image'] : task_name
    image_tag = task.has_key?('tag') ? "#{task['tag']}" : 'latest'
    image_tag = task.has_key?('tag_param') ? Ref("#{task['tag_param']}") : image_tag

    # create main definition
    task_def =  {
      Name: name,
      Image: FnJoin('',[ image_repo, image_name, ":", image_tag ]),
      LogConfiguration: {
        LogDriver: 'awslogs',
        Options: {
          'awslogs-group' => Ref("LogGroup"),
          "awslogs-region" => Ref("AWS::Region"),
          "awslogs-stream-prefix" => name
        }
      }
    }

    task_def.merge!({ MemoryReservation: task['memory'] }) if task.has_key?('memory')
    task_def.merge!({ Memory: task['memory_hard'] }) if task.has_key?('memory_hard')
    task_def.merge!({ Cpu: task['cpu'] }) if task.has_key?('cpu')

    task_def.merge!({ Ulimits: task['ulimits'] }) if task.has_key?('ulimits')



    if !(task['env_vars'].nil?)
      task['env_vars'].each do |name,value|
        split_value = value.to_s.split(/\${|}/)
        if split_value.include? 'environment'
          fn_join = split_value.map { |x| x == 'environment' ? [ Ref('EnvironmentName'), '.', FnFindInMap('AccountId',Ref('AWS::AccountId'),'DnsDomain') ] : x }
          env_value = FnJoin('', fn_join.flatten)
        elsif value == 'cf_version'
          env_value = cf_version
        else
          env_value = value
        end
        env_vars << { Name: name, Value: env_value}
      end
    end

    task_def.merge!({Environment: env_vars }) if env_vars.any?

    # add links
    if task.key?('links')
      if task['links'].kind_of?(Array)
        task_def.merge!({ Links: task['links'] })
      end
    end

    # add entrypoint
    if task.key?('entrypoint')
      if task['entrypoint'].kind_of?(Array)
        task_def.merge!({ EntryPoint: task['entrypoint'] })
      end
    end

    # By default Essential is true, switch to false if `not_essential: true`
    task_def.merge!({ Essential: false }) if task['not_essential']

    # add docker volumes
    if task.key?('mounts')
      task['mounts'].each do |mount|
        if mount.is_a? String
          parts = mount.split(':',2)
          mount_points << { ContainerPath: FnSub(parts[0]), SourceVolume: FnSub(parts[1]), ReadOnly: (parts[2] == 'ro' ? true : false) }
        else
          mount_points << mount
        end
      end
      task_def.merge!({MountPoints: mount_points })
    end

    # add volumes from
    if task.key?('volumes_from')
      if task['volumes_from'].kind_of?(Array)
        task['volumes_from'].each do |source_container|
          volumes_from << { SourceContainer: source_container }
        end
        task_def.merge!({ VolumesFrom: volumes_from })
      end
    end

    # add port
    if task.key?('ports')
      task['ports'].each do |port|
        port_array = port.to_s.split(":").map(&:to_i)
        mapping = {}
        mapping.merge!(ContainerPort: port_array[0])
        mapping.merge!(HostPort: port_array[1]) if port_array.length == 2
        port_mappings << mapping
      end
      task_def.merge!({PortMappings: port_mappings})
    end

    # add DependsOn
    # The dependencies defined for container startup and shutdown. A container can contain multiple dependencies. When a dependency is defined for container startup, for container shutdown it is reversed.
    # For tasks using the EC2 launch type, the container instances require at least version 1.3.0 of the container agent to enable container dependencies
    depends_on = []
    if !(task['depends_on'].nil?)
      task['depends_on'].each do |name,value|
        depends_on << { ContainerName: name, Condition: value}
      end
    end
    
    linux_parameters = {}
    
    if task.key?('cap_add')
      linux_parameters[:Capabilities] = {Add: task['cap_add']}
    end
    
    if task.key?('cap_drop')
      if linux_parameters.key?(:Capabilities)
        linux_parameters[:Capabilities][:Drop] = task['cap_drop']
      else
        linux_parameters[:Capabilities] = {Drop: task['cap_drop']}
      end
    end
    
    if task.key?('init')
      linux_parameters[:InitProcessEnabled] = task['init']
    end
    
    if task.key?('memory_swap')
      linux_parameters[:MaxSwap] = task['memory_swap'].to_i
    end
    
    if task.key?('shm_size')
      linux_parameters[:SharedMemorySize] = task['shm_size'].to_i
    end
    
    if task.key?('memory_swappiness')
      linux_parameters[:Swappiness] = task['memory_swappiness'].to_i
    end
    
    task_def.merge!({LinuxParameters: linux_parameters}) if linux_parameters.any?
    task_def.merge!({EntryPoint: task['entrypoint'] }) if task.key?('entrypoint')
    task_def.merge!({Command: task['command'] }) if task.key?('command')
    task_def.merge!({HealthCheck: task['healthcheck'] }) if task.key?('healthcheck')
    task_def.merge!({WorkingDirectory: task['working_dir'] }) if task.key?('working_dir')
    task_def.merge!({Privileged: task['privileged'] }) if task.key?('privileged')
    task_def.merge!({User: task['user'] }) if task.key?('user')
    task_def.merge!({DependsOn: depends_on }) if depends_on.length > 0
    task_def.merge!({ ExtraHosts: task['extra_hosts'] }) if task.has_key?('extra_hosts')


    if task.key?('secrets')
      
      if task['secrets'].key?('ssm')
        secrets.push *task['secrets']['ssm'].map {|k,v| { Name: k, ValueFrom: v.is_a?(String) && v.start_with?('/') ? FnSub("arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter#{v}") : v }}
        resources = task['secrets']['ssm'].map {|k,v| v.is_a?(String) && v.start_with?('/') ? FnSub("arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter#{v}") : v }
        secrets_policy['ssm-secrets'] = {
          'action' => 'ssm:GetParameters',
          'resource' => resources
        }
      end
      
      if task['secrets'].key?('secretsmanager')
        secrets.push *task['secrets']['secretsmanager'].map {|k,v| { Name: k, ValueFrom: v.is_a?(String) && v.start_with?('/') ? FnSub("arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:#{v}") : v }}
        resources = task['secrets']['secretsmanager'].map {|k,v| v.is_a?(String) && v.start_with?('/') ? FnSub("arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:#{v}-*") : v }
        secrets_policy['secretsmanager'] = {
          'action' => 'secretsmanager:GetSecretValue',
          'resource' => resources
        }
      end
      
      if secrets.any?
        task_def.merge!({Secrets: secrets})
      end
      
    end

    definitions << task_def

  end

  # add docker volumes
  volumes = external_parameters.fetch(:volumes, [])
  volumes.each do |volume|
    if volume.is_a? String
      parts = volume.split(':')
      object = { Name: FnSub(parts[0])}
      object.merge!({ Host: { SourcePath: FnSub(parts[1]) }}) if parts[1]
    else
      object = volume
    end
    task_volumes << object
  end

  # add task placement constraints 
  task_constraints =[];
  task_placement_constraints = external_parameters.fetch(:task_placement_constraints, [])
  task_placement_constraints.each do |cntr|
    object = {Type: "memberOf"} 
    object.merge!({ Expression: FnSub(cntr)})
    task_constraints << object
  end


  iam_policies = external_parameters.fetch(:iam_policies, {})
  service_discovery = external_parameters.fetch(:service_discovery, {})
  unless iam_policies.empty?

    unless service_discovery.empty?
      iam_policies['ecs-service-discovery'] = {
        'action' => %w(
          servicediscovery:RegisterInstance
          servicediscovery:DeregisterInstance
          servicediscovery:DiscoverInstances
          servicediscovery:Get*
          servicediscovery:List*
          route53:GetHostedZone
          route53:ListHostedZonesByName
          route53:ChangeResourceRecordSets
          route53:CreateHealthCheck
          route53:GetHealthCheck
          route53:DeleteHealthCheck
          route53:UpdateHealthCheck
        )
      }
    end

    IAM_Role('TaskRole') do
      AssumeRolePolicyDocument service_assume_role_policy(['ecs-tasks','ssm'])
      Path '/'
      Policies(iam_role_policies(iam_policies))
    end

    IAM_Role('ExecutionRole') do
      AssumeRolePolicyDocument service_assume_role_policy(['ecs-tasks','ssm'])
      Path '/'
      ManagedPolicyArns ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]

      if secrets_policy.any?
        Policies iam_role_policies(secrets_policy)
      end

    end
  end

  ECS_TaskDefinition('Task') do
    ContainerDefinitions definitions


    if external_parameters[:cpu]
      Cpu external_parameters[:cpu]
    end

    if external_parameters[:memory]
      Memory external_parameters[:memory]
    end

    unless network_mode.empty?
      NetworkMode network_mode
    end

    if task_volumes.any?
      Volumes task_volumes
    end

    unless iam_policies.empty?
      TaskRoleArn Ref('TaskRole')
      ExecutionRoleArn Ref('ExecutionRole')
    end

    if task_constraints.any?
      PlacementConstraints task_constraints 
    end

    if awsvpc_enabled
        RequiresCompatibilities FnIf('IsFargate', ['FARGATE'], ['EC2'])
    end

    Tags tags

  end unless task_definition.empty?

  service_loadbalancer = []
  targetgroup = external_parameters.fetch(:targetgroup, {})
  rule_names = []
  unless targetgroup.empty?

    if targetgroup.has_key?('rules')

      attributes = []

      targetgroup['attributes'].each do |key,value|
        attributes << { Key: key, Value: value }
      end if targetgroup.has_key?('attributes')

      tg_tags = tags.map(&:clone)

      targetgroup['tags'].each do |key,value|
        tg_tags << { Key: key, Value: value }
      end if targetgroup.has_key?('tags')

      ElasticLoadBalancingV2_TargetGroup('TaskTargetGroup') do
        ## Required
        Port targetgroup['port']
        Protocol targetgroup['protocol'].upcase
        VpcId Ref('VPCId')
        ## Optional
        if targetgroup.has_key?('healthcheck')
          HealthCheckPort targetgroup['healthcheck']['port'] if targetgroup['healthcheck'].has_key?('port')
          HealthCheckProtocol targetgroup['healthcheck']['protocol'] if targetgroup['healthcheck'].has_key?('port')
          HealthCheckIntervalSeconds targetgroup['healthcheck']['interval'] if targetgroup['healthcheck'].has_key?('interval')
          HealthCheckTimeoutSeconds targetgroup['healthcheck']['timeout'] if targetgroup['healthcheck'].has_key?('timeout')
          HealthyThresholdCount targetgroup['healthcheck']['healthy_count'] if targetgroup['healthcheck'].has_key?('healthy_count')
          UnhealthyThresholdCount targetgroup['healthcheck']['unhealthy_count'] if targetgroup['healthcheck'].has_key?('unhealthy_count')
          HealthCheckPath targetgroup['healthcheck']['path'] if targetgroup['healthcheck'].has_key?('path')
          Matcher ({ HttpCode: targetgroup['healthcheck']['code'] }) if targetgroup['healthcheck'].has_key?('code')
        end

        TargetType targetgroup['type'] if targetgroup.has_key?('type')
        TargetGroupAttributes attributes if attributes.any?

        Tags tg_tags
      end

      targetgroup['rules'].each_with_index do |rule, index|
        listener_conditions = []
        if rule.key?("path")
          listener_conditions << { Field: "path-pattern", Values: [ rule["path"] ] }
        end
        if rule.key?("host")
          hosts = []
          if rule["host"].include?('.') || rule["host"].key?("Fn::Join")
            hosts << rule["host"]
          else
            hosts << FnJoin("", [ rule["host"], ".", Ref("EnvironmentName"), ".", Ref('DnsDomain') ])
          end
          listener_conditions << { Field: "host-header", Values: hosts }
        end

        if rule.key?("name")
          rule_name = rule['name']
        elsif rule['priority'].is_a? Integer
          rule_name = "TargetRule#{rule['priority']}"
        else
          rule_name = "TargetRule#{index}"
        end
        rule_names << rule_name

        ElasticLoadBalancingV2_ListenerRule(rule_name) do
          Actions [{ Type: "forward", TargetGroupArn: Ref('TaskTargetGroup') }]
          Conditions listener_conditions
          ListenerArn Ref("Listener")
          Priority rule['priority']
        end

      end

      targetgroup_arn = Ref('TaskTargetGroup')
    else
      targetgroup_arn = Ref('TargetGroup')
    end

    service_loadbalancer << {
      ContainerName: targetgroup['container'],
      ContainerPort: targetgroup['port'],
      TargetGroupArn: targetgroup_arn
    }
  end

  unless awsvpc_enabled
    IAM_Role('Role') do
      AssumeRolePolicyDocument service_assume_role_policy('ecs')
      Path '/'
      ManagedPolicyArns ["arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"]
    end
  end


  securityGroups = external_parameters.fetch(:securityGroups, [])
  security_group_rules = external_parameters.fetch(:security_group_rules, [])
  if awsvpc_enabled == true
    sg_name = 'SecurityGroupBackplane'
    if ((!securityGroups.empty?) && (securityGroups.has_key?(external_parameters[:component_name])))
      EC2_SecurityGroup('ServiceSecurityGroup') do
        VpcId Ref('VPCId')
        GroupDescription "#{external_parameters[:component_name]} ECS service"
        SecurityGroupIngress sg_create_rules(securityGroups[external_parameters[:component_name]], ip_blocks)
      end
      sg_name = 'ServiceSecurityGroup'
    elsif (security_group_rules.any?)
      EC2_SecurityGroup(:ServiceSecurityGroup) {
        VpcId Ref(:VPCId)
        GroupDescription "#{external_parameters[:component_name]} ECS service"
        SecurityGroupIngress generate_security_group_rules(security_group_rules,ip_blocks)
        Tags tags
      }
      sg_name = 'ServiceSecurityGroup'
    end
    
    Output(:SecurityGroup) {
      Value(Ref(sg_name))
      Export FnSub("${EnvironmentName}-#{export}-SecurityGroup")
    }
  end

  registry = {}

  unless service_discovery.empty?

    ServiceDiscovery_Service(:ServiceRegistry) {
      NamespaceId Ref(:NamespaceId)
      Name service_discovery['name']  if service_discovery.has_key? 'name'
      DnsConfig({
        DnsRecords: [{
          TTL: 60,
          Type: 'A'
        }],
        RoutingPolicy: 'WEIGHTED'
      })
      if service_discovery.has_key? 'healthcheck'
        HealthCheckConfig service_discovery['healthcheck']
      else
        HealthCheckCustomConfig ({ FailureThreshold: (service_discovery['failure_threshold'] || 1) })
      end
    }

    registry[:RegistryArn] = FnGetAtt(:ServiceRegistry, :Arn)
    registry[:ContainerName] = service_discovery['container_name']
    registry[:ContainerPort] = service_discovery['container_port'] if service_discovery.has_key? 'container_port'
    registry[:Port] = service_discovery['port'] if service_discovery.has_key? 'port'
  end


  strategy = external_parameters.fetch(:scheduling_strategy, nil)
  task_placement_distinct_instance_constraint = external_parameters.fetch(:distinct_instance_constraint, false)
  health_check_grace_period = external_parameters.fetch(:health_check_grace_period, nil)
  placement_strategies = external_parameters.fetch(:placement_strategies, nil)
  ECS_Service('Service') do
    DependsOn rule_names if rule_names.any?
    if awsvpc_enabled
        LaunchType FnIf('IsEmptyLaunchType', Ref('AWS::NoValue'), FnIf('IsFargate', 'FARGATE', 'EC2'))
    end
    Cluster Ref("EcsCluster")
    HealthCheckGracePeriodSeconds health_check_grace_period if !health_check_grace_period.nil?
    DesiredCount Ref('DesiredCount') if strategy != 'DAEMON'
    DeploymentConfiguration ({
        MinimumHealthyPercent: Ref('MinimumHealthyPercent'),
        MaximumPercent: Ref('MaximumPercent')
    })
    TaskDefinition Ref('Task')
    SchedulingStrategy scheduling_strategy if !strategy.nil?
    PlacementStrategies placement_strategies if !placement_strategies.nil?
    PlacementConstraints [{Type: "distinctInstance"}] if task_placement_distinct_instance_constraint

    if service_loadbalancer.any?
      Role Ref('Role') unless awsvpc_enabled
      LoadBalancers service_loadbalancer
    end

    if awsvpc_enabled == true
      NetworkConfiguration({
        AwsvpcConfiguration: {
          AssignPublicIp: "DISABLED",
          SecurityGroups: [ Ref(sg_name) ],
          Subnets: Ref('SubnetIds')
        }
      })
    end

    unless registry.empty?
      ServiceRegistries([registry])
    end

    Tags tags if tags.any?

  end unless task_definition.empty?


  scaling_policy = external_parameters.fetch(:scaling_policy, {})
  unless scaling_policy.empty?

    IAM_Role(:ServiceECSAutoScaleRole) {
      Condition 'IsScalingEnabled'
      AssumeRolePolicyDocument service_assume_role_policy('application-autoscaling')
      Path '/'
      Policies ([
        PolicyName: 'ecs-scaling',
        PolicyDocument: {
          Statement: [
            {
              Effect: "Allow",
              Action: ['cloudwatch:DescribeAlarms','cloudwatch:PutMetricAlarm','cloudwatch:DeleteAlarms'],
              Resource: "*"
            },
            {
              Effect: "Allow",
              Action: ['ecs:UpdateService','ecs:DescribeServices'],
              Resource: Ref('Service')
            }
          ]
      }])
    }

    ApplicationAutoScaling_ScalableTarget(:ServiceScalingTarget) {
      Condition 'IsScalingEnabled'
      MaxCapacity scaling_policy['max']
      MinCapacity scaling_policy['min']
      ResourceId FnJoin( '', [ "service/", Ref('EcsCluster'), "/", FnGetAtt(:Service,:Name) ] )
      RoleARN FnGetAtt(:ServiceECSAutoScaleRole,:Arn)
      ScalableDimension "ecs:service:DesiredCount"
      ServiceNamespace "ecs"
    }
    
    default_alarm = {}
    default_alarm['metric_name'] = 'CPUUtilization'
    default_alarm['namespace'] = 'AWS/ECS'
    default_alarm['statistic'] = 'Average'
    default_alarm['period'] = '60'
    default_alarm['evaluation_periods'] = '5'
    default_alarm['dimentions'] = [
      { Name: 'ServiceName', Value: FnGetAtt(:Service,:Name)},
      { Name: 'ClusterName', Value: Ref('EcsCluster')}
    ]


    if scaling_policy['up'].kind_of?(Hash)
      scaling_policy['up'] = [scaling_policy['up']]
    end

    if scaling_policy['down'].kind_of?(Hash)
      scaling_policy['down'] = [scaling_policy['down']]
    end

    scaling_policy['up'].each_with_index do |scale_up_policy, i|
      logical_scaling_policy_name = "ServiceScalingUpPolicy"  + (i > 0 ? "#{i+1}" : "")
      logical_alarm_name          = "ServiceScaleUpAlarm"     + (i > 0 ? "#{i+1}" : "")
      policy_name                 = "scale-up-policy"         + (i > 0 ? "-#{i+1}" : "")
      
      ApplicationAutoScaling_ScalingPolicy(logical_scaling_policy_name) {
        Condition 'IsScalingEnabled'
        PolicyName FnJoin('-', [ Ref('EnvironmentName'), component_name, policy_name])
        PolicyType "StepScaling"
        ScalingTargetId Ref(:ServiceScalingTarget)
        StepScalingPolicyConfiguration({
          AdjustmentType: "ChangeInCapacity",
          Cooldown: scale_up_policy['cooldown'] || 300,
          MetricAggregationType: "Average",
          StepAdjustments: [{ ScalingAdjustment: scale_up_policy['adjustment'].to_s, MetricIntervalLowerBound: 0 }]
        })
      }

      CloudWatch_Alarm(logical_alarm_name) {
        Condition 'IsScalingEnabled'
        AlarmDescription FnJoin(' ', [Ref('EnvironmentName'), "#{component_name} ecs scale up alarm"])
        MetricName scale_up_policy['metric_name'] || default_alarm['metric_name']
        Namespace scale_up_policy['namespace'] || default_alarm['namespace']
        Statistic scale_up_policy['statistic'] || default_alarm['statistic']
        Period (scale_up_policy['period'] || default_alarm['period']).to_s
        EvaluationPeriods scale_up_policy['evaluation_periods'].to_s
        Threshold scale_up_policy['threshold'].to_s
        AlarmActions [Ref(logical_scaling_policy_name)]
        ComparisonOperator 'GreaterThanThreshold'
        Dimensions scale_up_policy['dimentions'] || default_alarm['dimentions']
      }
    end

    scaling_policy['down'].each_with_index do |scale_down_policy, i|
      logical_scaling_policy_name = "ServiceScalingDownPolicy"  + (i > 0 ? "#{i+1}" : "")
      logical_alarm_name          = "ServiceScaleDownAlarm"     + (i > 0 ? "#{i+1}" : "")
      policy_name                 = "scale-down-policy"         + (i > 0 ? "-#{i+1}" : "")

      ApplicationAutoScaling_ScalingPolicy(logical_scaling_policy_name) {
        Condition 'IsScalingEnabled'
        PolicyName FnJoin('-', [ Ref('EnvironmentName'), component_name, policy_name])
        PolicyType 'StepScaling'
        ScalingTargetId Ref(:ServiceScalingTarget)
        StepScalingPolicyConfiguration({
          AdjustmentType: "ChangeInCapacity",
          Cooldown: scale_down_policy['cooldown'] || 900,
          MetricAggregationType: "Average",
          StepAdjustments: [{ ScalingAdjustment: scale_down_policy['adjustment'].to_s, MetricIntervalUpperBound: 0 }]
        })
      }

      CloudWatch_Alarm(logical_alarm_name) {
        Condition 'IsScalingEnabled'
        AlarmDescription FnJoin(' ', [Ref('EnvironmentName'), "#{component_name} ecs scale down alarm"])
        MetricName scale_down_policy['metric_name'] || default_alarm['metric_name']
        Namespace scale_down_policy['namespace'] || default_alarm['namespace']
        Statistic scale_down_policy['statistic'] || default_alarm['statistic']
        Period (scale_down_policy['period'] || default_alarm['period']).to_s
        EvaluationPeriods scale_down_policy['evaluation_periods'].to_s
        Threshold scale_down_policy['threshold'].to_s
        AlarmActions [Ref(logical_scaling_policy_name)]
        ComparisonOperator 'LessThanThreshold'
        Dimensions scale_down_policy['dimentions'] || default_alarm['dimentions']
      }
    end
  end

  Output("ServiceName") do
    Value(FnGetAtt(:Service, :Name))
    Export FnSub("${EnvironmentName}-#{export}-ServiceName")
  end unless task_definition.empty?

end
