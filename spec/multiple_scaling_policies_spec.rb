require 'yaml'

describe 'compiled component ecs-service' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/multiple_scaling_policies.test.yaml")).to be_truthy
    end      
  end
  
  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/multiple_scaling_policies/ecs-service.compiled.yaml") }
  
  context "Resource" do

    
    context "LogGroup" do
      let(:resource) { template["Resources"]["LogGroup"] }

      it "is of type AWS::Logs::LogGroup" do
          expect(resource["Type"]).to eq("AWS::Logs::LogGroup")
      end
      
      it "to have property LogGroupName" do
          expect(resource["Properties"]["LogGroupName"]).to eq({"Ref"=>"AWS::StackName"})
      end
      
      it "to have property RetentionInDays" do
          expect(resource["Properties"]["RetentionInDays"]).to eq("7")
      end
      
    end
    
    context "Task" do
      let(:resource) { template["Resources"]["Task"] }

      it "is of type AWS::ECS::TaskDefinition" do
          expect(resource["Type"]).to eq("AWS::ECS::TaskDefinition")
      end
      
      it "to have property ContainerDefinitions" do
          expect(resource["Properties"]["ContainerDefinitions"]).to eq([{"Name"=>"nginx", "Image"=>{"Fn::Join"=>["", ["nginx/", "nginx", ":", "latest"]]}, "LogConfiguration"=>{"LogDriver"=>"awslogs", "Options"=>{"awslogs-group"=>{"Ref"=>"LogGroup"}, "awslogs-region"=>{"Ref"=>"AWS::Region"}, "awslogs-stream-prefix"=>"nginx"}}}])
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Name", "Value"=>"ecs-service"}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
      end
      
    end
    
    context "Role" do
      let(:resource) { template["Resources"]["Role"] }

      it "is of type AWS::IAM::Role" do
          expect(resource["Type"]).to eq("AWS::IAM::Role")
      end
      
      it "to have property AssumeRolePolicyDocument" do
          expect(resource["Properties"]["AssumeRolePolicyDocument"]).to eq({"Version"=>"2012-10-17", "Statement"=>[{"Effect"=>"Allow", "Principal"=>{"Service"=>"ecs.amazonaws.com"}, "Action"=>"sts:AssumeRole"}]})
      end
      
      it "to have property Path" do
          expect(resource["Properties"]["Path"]).to eq("/")
      end
      
      it "to have property ManagedPolicyArns" do
          expect(resource["Properties"]["ManagedPolicyArns"]).to eq(["arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"])
      end
      
    end
    
    context "Service" do
      let(:resource) { template["Resources"]["Service"] }

      it "is of type AWS::ECS::Service" do
          expect(resource["Type"]).to eq("AWS::ECS::Service")
      end
      
      it "to have property Cluster" do
          expect(resource["Properties"]["Cluster"]).to eq({"Ref"=>"EcsCluster"})
      end
      
      it "to have property DesiredCount" do
          expect(resource["Properties"]["DesiredCount"]).to eq({"Ref"=>"DesiredCount"})
      end
      
      it "to have property DeploymentConfiguration" do
          expect(resource["Properties"]["DeploymentConfiguration"]).to eq({"MinimumHealthyPercent"=>{"Ref"=>"MinimumHealthyPercent"}, "MaximumPercent"=>{"Ref"=>"MaximumPercent"}})
      end
      
      it "to have property TaskDefinition" do
          expect(resource["Properties"]["TaskDefinition"]).to eq({"Ref"=>"Task"})
      end
      
      it "to have property Role" do
          expect(resource["Properties"]["Role"]).to eq({"Ref"=>"Role"})
      end
      
      it "to have property LoadBalancers" do
          expect(resource["Properties"]["LoadBalancers"]).to eq([{"ContainerName"=>"nginx", "ContainerPort"=>80, "TargetGroupArn"=>{"Ref"=>"TargetGroup"}}])
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Name", "Value"=>"ecs-service"}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
      end
      
    end
    
    context "ServiceECSAutoScaleRole" do
      let(:resource) { template["Resources"]["ServiceECSAutoScaleRole"] }

      it "is of type AWS::IAM::Role" do
          expect(resource["Type"]).to eq("AWS::IAM::Role")
      end
      
      it "to have property AssumeRolePolicyDocument" do
          expect(resource["Properties"]["AssumeRolePolicyDocument"]).to eq({"Version"=>"2012-10-17", "Statement"=>[{"Effect"=>"Allow", "Principal"=>{"Service"=>"application-autoscaling.amazonaws.com"}, "Action"=>"sts:AssumeRole"}]})
      end
      
      it "to have property Path" do
          expect(resource["Properties"]["Path"]).to eq("/")
      end
      
      it "to have property Policies" do
          expect(resource["Properties"]["Policies"]).to eq([{"PolicyName"=>"ecs-scaling", "PolicyDocument"=>{"Statement"=>[{"Effect"=>"Allow", "Action"=>["cloudwatch:DescribeAlarms", "cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms"], "Resource"=>"*"}, {"Effect"=>"Allow", "Action"=>["ecs:UpdateService", "ecs:DescribeServices"], "Resource"=>{"Ref"=>"Service"}}]}}])
      end
      
    end
    
    context "ServiceScalingTarget" do
      let(:resource) { template["Resources"]["ServiceScalingTarget"] }

      it "is of type AWS::ApplicationAutoScaling::ScalableTarget" do
          expect(resource["Type"]).to eq("AWS::ApplicationAutoScaling::ScalableTarget")
      end
      
      it "to have property MaxCapacity" do
          expect(resource["Properties"]["MaxCapacity"]).to eq(4)
      end
      
      it "to have property MinCapacity" do
          expect(resource["Properties"]["MinCapacity"]).to eq(2)
      end
      
      it "to have property ResourceId" do
          expect(resource["Properties"]["ResourceId"]).to eq({"Fn::Join"=>["", ["service/", {"Ref"=>"EcsCluster"}, "/", {"Fn::GetAtt"=>["Service", "Name"]}]]})
      end
      
      it "to have property RoleARN" do
          expect(resource["Properties"]["RoleARN"]).to eq({"Fn::GetAtt"=>["ServiceECSAutoScaleRole", "Arn"]})
      end
      
      it "to have property ScalableDimension" do
          expect(resource["Properties"]["ScalableDimension"]).to eq("ecs:service:DesiredCount")
      end
      
      it "to have property ServiceNamespace" do
          expect(resource["Properties"]["ServiceNamespace"]).to eq("ecs")
      end
      
    end
    
    context "ServiceScalingUpPolicy" do
      let(:resource) { template["Resources"]["ServiceScalingUpPolicy"] }

      it "is of type AWS::ApplicationAutoScaling::ScalingPolicy" do
          expect(resource["Type"]).to eq("AWS::ApplicationAutoScaling::ScalingPolicy")
      end
      
      it "to have property PolicyName" do
          expect(resource["Properties"]["PolicyName"]).to eq({"Fn::Join"=>["-", [{"Ref"=>"EnvironmentName"}, "ecs-service", "scale-up-policy"]]})
      end
      
      it "to have property PolicyType" do
          expect(resource["Properties"]["PolicyType"]).to eq("StepScaling")
      end
      
      it "to have property ScalingTargetId" do
          expect(resource["Properties"]["ScalingTargetId"]).to eq({"Ref"=>"ServiceScalingTarget"})
      end
      
      it "to have property StepScalingPolicyConfiguration" do
          expect(resource["Properties"]["StepScalingPolicyConfiguration"]).to eq({"AdjustmentType"=>"ChangeInCapacity", "Cooldown"=>150, "MetricAggregationType"=>"Average", "StepAdjustments"=>[{"ScalingAdjustment"=>"2", "MetricIntervalLowerBound"=>0}]})
      end
      
    end
    
    context "ServiceScaleUpAlarm" do
      let(:resource) { template["Resources"]["ServiceScaleUpAlarm"] }

      it "is of type AWS::CloudWatch::Alarm" do
          expect(resource["Type"]).to eq("AWS::CloudWatch::Alarm")
      end
      
      it "to have property AlarmDescription" do
          expect(resource["Properties"]["AlarmDescription"]).to eq({"Fn::Join"=>[" ", [{"Ref"=>"EnvironmentName"}, "ecs-service ecs scale up alarm"]]})
      end
      
      it "to have property MetricName" do
          expect(resource["Properties"]["MetricName"]).to eq("CPUUtilization")
      end
      
      it "to have property Namespace" do
          expect(resource["Properties"]["Namespace"]).to eq("AWS/ECS")
      end
      
      it "to have property Statistic" do
          expect(resource["Properties"]["Statistic"]).to eq("Average")
      end
      
      it "to have property Period" do
          expect(resource["Properties"]["Period"]).to eq("60")
      end
      
      it "to have property EvaluationPeriods" do
          expect(resource["Properties"]["EvaluationPeriods"]).to eq("5")
      end
      
      it "to have property Threshold" do
          expect(resource["Properties"]["Threshold"]).to eq("90")
      end
      
      it "to have property AlarmActions" do
          expect(resource["Properties"]["AlarmActions"]).to eq([{"Ref"=>"ServiceScalingUpPolicy"}])
      end
      
      it "to have property ComparisonOperator" do
          expect(resource["Properties"]["ComparisonOperator"]).to eq("GreaterThanThreshold")
      end
      
      it "to have property Dimensions" do
          expect(resource["Properties"]["Dimensions"]).to eq([{"Name"=>"ServiceName", "Value"=>{"Fn::GetAtt"=>["Service", "Name"]}}, {"Name"=>"ClusterName", "Value"=>{"Ref"=>"EcsCluster"}}])
      end
      
    end
    
    context "ServiceScalingUpPolicy2" do
      let(:resource) { template["Resources"]["ServiceScalingUpPolicy2"] }

      it "is of type AWS::ApplicationAutoScaling::ScalingPolicy" do
          expect(resource["Type"]).to eq("AWS::ApplicationAutoScaling::ScalingPolicy")
      end
      
      it "to have property PolicyName" do
          expect(resource["Properties"]["PolicyName"]).to eq({"Fn::Join"=>["-", [{"Ref"=>"EnvironmentName"}, "ecs-service", "scale-up-policy-2"]]})
      end
      
      it "to have property PolicyType" do
          expect(resource["Properties"]["PolicyType"]).to eq("StepScaling")
      end
      
      it "to have property ScalingTargetId" do
          expect(resource["Properties"]["ScalingTargetId"]).to eq({"Ref"=>"ServiceScalingTarget"})
      end
      
      it "to have property StepScalingPolicyConfiguration" do
          expect(resource["Properties"]["StepScalingPolicyConfiguration"]).to eq({"AdjustmentType"=>"ChangeInCapacity", "Cooldown"=>150, "MetricAggregationType"=>"Average", "StepAdjustments"=>[{"ScalingAdjustment"=>"1", "MetricIntervalLowerBound"=>0}]})
      end
      
    end
    
    context "ServiceScaleUpAlarm2" do
      let(:resource) { template["Resources"]["ServiceScaleUpAlarm2"] }

      it "is of type AWS::CloudWatch::Alarm" do
          expect(resource["Type"]).to eq("AWS::CloudWatch::Alarm")
      end
      
      it "to have property AlarmDescription" do
          expect(resource["Properties"]["AlarmDescription"]).to eq({"Fn::Join"=>[" ", [{"Ref"=>"EnvironmentName"}, "ecs-service ecs scale up alarm"]]})
      end
      
      it "to have property MetricName" do
          expect(resource["Properties"]["MetricName"]).to eq("CPUUtilization")
      end
      
      it "to have property Namespace" do
          expect(resource["Properties"]["Namespace"]).to eq("AWS/ECS")
      end
      
      it "to have property Statistic" do
          expect(resource["Properties"]["Statistic"]).to eq("Average")
      end
      
      it "to have property Period" do
          expect(resource["Properties"]["Period"]).to eq("60")
      end
      
      it "to have property EvaluationPeriods" do
          expect(resource["Properties"]["EvaluationPeriods"]).to eq("5")
      end
      
      it "to have property Threshold" do
          expect(resource["Properties"]["Threshold"]).to eq("70")
      end
      
      it "to have property AlarmActions" do
          expect(resource["Properties"]["AlarmActions"]).to eq([{"Ref"=>"ServiceScalingUpPolicy2"}])
      end
      
      it "to have property ComparisonOperator" do
          expect(resource["Properties"]["ComparisonOperator"]).to eq("GreaterThanThreshold")
      end
      
      it "to have property Dimensions" do
          expect(resource["Properties"]["Dimensions"]).to eq([{"Name"=>"ServiceName", "Value"=>{"Fn::GetAtt"=>["Service", "Name"]}}, {"Name"=>"ClusterName", "Value"=>{"Ref"=>"EcsCluster"}}])
      end
      
    end
    
    context "ServiceScalingDownPolicy" do
      let(:resource) { template["Resources"]["ServiceScalingDownPolicy"] }

      it "is of type AWS::ApplicationAutoScaling::ScalingPolicy" do
          expect(resource["Type"]).to eq("AWS::ApplicationAutoScaling::ScalingPolicy")
      end
      
      it "to have property PolicyName" do
          expect(resource["Properties"]["PolicyName"]).to eq({"Fn::Join"=>["-", [{"Ref"=>"EnvironmentName"}, "ecs-service", "scale-down-policy"]]})
      end
      
      it "to have property PolicyType" do
          expect(resource["Properties"]["PolicyType"]).to eq("StepScaling")
      end
      
      it "to have property ScalingTargetId" do
          expect(resource["Properties"]["ScalingTargetId"]).to eq({"Ref"=>"ServiceScalingTarget"})
      end
      
      it "to have property StepScalingPolicyConfiguration" do
          expect(resource["Properties"]["StepScalingPolicyConfiguration"]).to eq({"AdjustmentType"=>"ChangeInCapacity", "Cooldown"=>600, "MetricAggregationType"=>"Average", "StepAdjustments"=>[{"ScalingAdjustment"=>"-1", "MetricIntervalUpperBound"=>0}]})
      end
      
    end
    
    context "ServiceScaleDownAlarm" do
      let(:resource) { template["Resources"]["ServiceScaleDownAlarm"] }

      it "is of type AWS::CloudWatch::Alarm" do
          expect(resource["Type"]).to eq("AWS::CloudWatch::Alarm")
      end
      
      it "to have property AlarmDescription" do
          expect(resource["Properties"]["AlarmDescription"]).to eq({"Fn::Join"=>[" ", [{"Ref"=>"EnvironmentName"}, "ecs-service ecs scale down alarm"]]})
      end
      
      it "to have property MetricName" do
          expect(resource["Properties"]["MetricName"]).to eq("CPUUtilization")
      end
      
      it "to have property Namespace" do
          expect(resource["Properties"]["Namespace"]).to eq("AWS/ECS")
      end
      
      it "to have property Statistic" do
          expect(resource["Properties"]["Statistic"]).to eq("Average")
      end
      
      it "to have property Period" do
          expect(resource["Properties"]["Period"]).to eq("60")
      end
      
      it "to have property EvaluationPeriods" do
          expect(resource["Properties"]["EvaluationPeriods"]).to eq("5")
      end
      
      it "to have property Threshold" do
          expect(resource["Properties"]["Threshold"]).to eq("70")
      end
      
      it "to have property AlarmActions" do
          expect(resource["Properties"]["AlarmActions"]).to eq([{"Ref"=>"ServiceScalingDownPolicy"}])
      end
      
      it "to have property ComparisonOperator" do
          expect(resource["Properties"]["ComparisonOperator"]).to eq("LessThanThreshold")
      end
      
      it "to have property Dimensions" do
          expect(resource["Properties"]["Dimensions"]).to eq([{"Name"=>"ServiceName", "Value"=>{"Fn::GetAtt"=>["Service", "Name"]}}, {"Name"=>"ClusterName", "Value"=>{"Ref"=>"EcsCluster"}}])
      end
      
    end
    
  end

end