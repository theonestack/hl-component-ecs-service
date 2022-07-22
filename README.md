# ecs-service CfHighlander component

Creates the resources required to set up and serve a ECS service

```bash
kurgan add ecs-service
```

## Parameters

| Name | Use | Default | Global | Type | Allowed Values |
| ---- | --- | ------- | ------ | ---- | -------------- |
| EnvironmentName | Tagging | dev | true | string
| EnvironmentType | Tagging | development | true | string | ['development','production']
| EcsCluster | ECS cluster to run the service in | - | false | string
| VPCId | Id of the vpc required for creating a target group and security group | - | false | AWS::EC2::VPC::Id
| TargetGroup | pass through an existing target group ARN | - | false | string
| Listener | listener to attach the generated target group too | - | false | string
| LoadBalancer | `Deprecated` | - | false | string
| DesiredCount | desired count of ECS tasks to run for the service | 1 | false | string
| MinimumHealthyPercent | minimum percentage of healthy tasks to retain during a deployment | 100 | false | string
| MaximumPercent | maximum percentage of tasks to scale up to during a deployment | 200 | false | string
| SubnetIds | list of subnet ids to run your tasks in if using aws-vpc networking | - | false | comma delimited string
| SecurityGroupBackplane | pass through an existing security group id to the ECS service | - | false | string
| EnableFargate | set to true to run the ECS service in Fargate | false | false | string | ['true','false']
| DisableLaunchType | set to false to disable setting the ECS service property `LaunchType` to specify custom default providers | false | false | string | ['true','false']
| PlatformVersion | set the fargate platform version | - | false | string
| NamespaceId | set a service discovery namespace id | - | false | string


## Configuration

### Logging

By default the component setups cloudwatch logging by creating a log group and adding the config to the task definition.
To change the log retention in the log group set `log_retention`. Defaults to 7 days

```yaml
loggroup_name: 'myapp'
log_retention: 7
```

### Task Level CPU and Memory

This will set hard resource limits for the service, this is required for fargate services but can be set for services on EC2

```yaml
cpu: 256
memory: 256
```

### Task Definition

Multiple task definitions can be defined under the `task_definition` key

```yaml
task_definition:
  task-1:
    ...
  task-2:
    ...
```

This is the fulls et of config options for the task definition.

```yaml
task_definition:
  task-1:
    repo: public.ecr.aws
    image: my/app
    tag: latest
    tag_param: MyAppTag
    memory: 1024
    memory_hard: 1024
    cpu: 1024
    ports:
    - 8080
    - 8081:8888
    not_essential: false
    env_vars:
      KEY: value
    secrets:
      ssm:
        API_KEY: /nginx/${EnvironmentName}/api/key
        API_SECRET: /nginx/${EnvironmentName}/api/secret
      secretsmanager:
        DB_PASSWORD: /db/${EnvironmentName}/password
    ulimits:
    - HardLimit: 65000
      Name: nofile
      SoftLimit: 65000
    cap_add: 
      - ALL
    cap_drop: 
      - MKNOD
    init: true
    memory_swap: 10
    shm_size: 10
    memory_swappiness: 10
    entrypoint:
    - entrypoint.sh
    command:
    - run.sh
    healthcheck:
      Command: 
      - check.sh
      Interval: 30
      Retries: 3
      StartPeriod: 300
      Timeout: 5
    working_dir: /src
    privileged: false
    user: appuser
    extra_hosts:
    - Hostname: example.com
      IpAddress: 127.0.0.1
    depends_on:
      task-2: START
    links:
      - task-2:task-2
```

see bellow for details on these options

#### Container Image

Define the container image details such as repo, image name and tag

```yaml
task_definition:
  task-1:
    repo: public.ecr.aws
    image: my/app
    tag: latest
```

The tag can also be setup to pass through as a cloudformation runtime parameter by using the `tag_param` key instead of `tag`.

```yaml
task_definition:
  task-1:
    repo: public.ecr.aws
    image: my/app
    tag_param: MyAppTag
```

#### Container CPU and Memory

Container level resources can be defined with `memory` being a soft limit that can be breached and `memory_hard` being a hard limit.

```yaml
task_definition:
  task-1:
    memory: 1024
    memory_hard: 1024
    cpu: 1024
```

#### Ports

Port mappings allow containers to access ports on the host container instance to send or receive traffic. 
`ContainerPort:HostPort`

```yaml
task_definition:
  task-1:
    ports:
    - 8080
    - 8081:8888
```

#### Not Essential

if the container doesn't need to run like a data container then `not_essential` can be set to false to when it stops it doesn't kill the whole task.

```yaml
task_definition:
  task-1:
    not_essential: true
```

#### Environment Variables

to pass through environment variables use `env_vars` with key:value pairs 

```yaml
task_definition:
  task-1:
    env_vars:
      KEY: value
```

#### Secrets

pass though secrets to the container as environment variables. Supports both ssm parameter store and secrets manager.

```yaml
task_definition:
  task-1:
    secrets:
      ssm:
        API_KEY: /nginx/${EnvironmentName}/api/key
        API_SECRET: /nginx/${EnvironmentName}/api/secret
      secretsmanager:
        DB_PASSWORD: /db/${EnvironmentName}/password
```

Not required, but you can also specify a secrets policy to be attached to the _execution_ role, so ECS can retrieve it. If not specified, the secret above is added, but if you want to add a wildcard, you can do so with:
```yaml
  secrets_policy:
    envNameHere:
      action:
        - secretsmanager:GetSecretValue
        - kms:*
      resource:
        - Fn::Sub: arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:${EnvironmentName}/sneaky/allthesecrets*

```

#### ulimits

```yaml
task_definition:
  task-1:
    ulimits:
    - HardLimit: 65000
      Name: nofile
      SoftLimit: 65000
```

#### Linux Parameters

Specifies Linux-specific options that are applied to the container, such as Linux KernelCapabilities. 

```yaml
task_definition:
  task-1:
    cap_add: 
    - ALL
    cap_drop: 
    - MKNOD
    init: true
    memory_swap: 10
    shm_size: 10
    memory_swappiness: 10
```

#### Extrypoint and Command

The entry point and command that is passed to the container.

```yaml
task_definition:
  task-1:
    entrypoint:
    - entrypoint.sh
    command:
    - run.sh
```

#### Container Health Check

The container health check command and associated configuration parameters for the container. If the health check fails the task is terminated

```yaml
task_definition:
  task-1:
    healthcheck:
      Command: 
      - check.sh
      Interval: 30
      Retries: 3
      StartPeriod: 300
      Timeout: 5
```

#### Working Directory

The working directory in which to run commands inside the container.

```yaml
task_definition:
  task-1:
    working_dir: /src
```

#### Privileged

When this parameter is true, the container is given elevated privileges on the host container instance (similar to the root user).
**NOTE:** not recommended ...

```yaml
task_definition:
  task-1:
    privileged: false
```

#### Container User

The user to use inside the container.

```yaml
task_definition:
  task-1:
    user: appuser
```

#### Extra Hosts

A list of hostnames and IP address mappings to append to the /etc/hosts file on the container.

```yaml
task_definition:
  task-1:
    extra_hosts:
    - Hostname: example.com
      IpAddress: 127.0.0.1

```

#### Depends On

specifies the dependencies defined for container startup and shutdown.

```yaml
task_definition:
  task-1:
    depends_on:
      task-2: START
```

#### Links

The links parameter allows containers to communicate with each other without the need for port mappings. This parameter is only supported if the network mode of a task definition is bridge. 


```yaml
task_definition:
  task-1:
    links:
    - task-2:task-2
```

### Exports

to change the export name incase of naming conflicts you can override it using the `export` key. The default is the component name.

```yaml
export: myapp
```

### Daemon tasks

Run a daemon task on all ECS instances in the cluster

```yaml
scheduling_strategy: DAEMON
```

### Service Discovery / Service Registries

You can configure a service to be added to one or more Service Discovery Namespaces by creating multiple service registries.

#### Highlander file

If you choose to create multiple registries then you will need to create a custom parameter for each Namespace ID with the value set to import the export from the respective Service Discovery stack.

```yaml
# Single registry
parameter name: 'NamespaceId', value: FnImportValue(FnSub('${EnvironmentName}-servicediscovery-NamespaceId'))
# Suggestion for using multiple registries
parameter name: 'PrivateNamespaceId', value: FnImportValue(FnSub('${EnvironmentName}-servicediscoveryprivate-NamespaceId'))
parameter name: 'PublicNamespaceId', value: FnImportValue(FnSub('${EnvironmentName}-servicediscoverypublic-NamespaceId'))
```

#### Config file

The `namespace_id` key is configured to do a FnSub on the value, so you can reference the parameter. The `failure_threshold`, `healthcheck`, `port` and `container_port` keys are optional.

```yaml
service_discovery_registries:
  tasknameprivate:
    namespace_id: ${PrivateNamespaceId}     # If there is only going to be one namespace then this can be changed to ${NamespaceId}
    name: task_name
    container_name: container_name
    container_port: 1433
    healthcheck: /
    failure_threshold: 2
  # Additional namespaces/registries below
  tasknamepublic:
    namespace_id: ${PublicNamespaceId}
    name: task_name
    container_name: container_name
    port: 5432
```

## Resources

### TaskRole

**Type:** AWS::IAM::Role

**Condition:** if `iam_policies` config contains policies

IAM permissions for the ECS service tasks runtime


### ExecutionRole

**Type:** AWS::IAM::Role

**Condition:** if `iam_policies` config contains policies

IAM permissions or the ECS agent to make AWS API calls on your behalf such as retrieve secrets. Default managed policy uses `arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy`


### Role

**Type:** AWS::IAM::Role

IAM permissions for the ECS service such as add and remove tasks from a target group. Default managed policy uses `arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole`


### Task

**Type:** AWS::ECS::TaskDefinition


### Service

**Type:** AWS::ECS::TaskDefinition


### LogGroup

**Type:** AWS::Logs::LogGroup

Cloudwatch log group for the tasks to send logs too


### TargetGroup

**Type:** AWS::ElasticLoadBalancingV2::TargetGroup

**Condition:** if `target_groups` config contains a list of target groups

Creates a target group resource per target group defined in the config


### ListenerRule

**Type:** AWS::ElasticLoadBalancingV2::ListenerRule

**Condition:** if `target_groups` config contains a target groups with rules

Creates a listener rule for the supplied listener for each rule defined on the target group


### ServiceSecurityGroup

**Type:** AWS::EC2::SecurityGroup

**Condition:** if `security_group_rules` config contains rules

Creates a security group with defined rules and attaches it to the ECS task if using `aws-vpc` networking


### ServiceRegistry

**Type:** AWS::ServiceDiscovery::Service

**Condition:** if `service_discovery` config is defined


## Outputs

| Name | Value | Export |
| ---- | --- | ------- |
| SecurityGroup | Security group name | ${EnvironmentName}-ecs-service-SecurityGroup
| ServiceName | ECS service name | ${EnvironmentName}-ecs-service-ServiceName
