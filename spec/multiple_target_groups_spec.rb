require 'yaml'

describe 'compiled component ecs-service' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/multiple_target_groups.test.yaml")).to be_truthy
    end      
  end
  
  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/multiple_target_groups/ecs-service.compiled.yaml") }
  
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
          expect(resource["Properties"]["ContainerDefinitions"]).to eq([{"Name"=>"nginx", "Image"=>{"Fn::Join"=>["", ["nginx/", "nginx", ":", "latest"]]}, "LogConfiguration"=>{"LogDriver"=>"awslogs", "Options"=>{"awslogs-group"=>{"Ref"=>"LogGroup"}, "awslogs-region"=>{"Ref"=>"AWS::Region"}, "awslogs-stream-prefix"=>"nginx"}}, "PortMappings"=>[{"ContainerPort"=>80}, {"ContainerPort"=>443}]}])
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Name", "Value"=>"ecs-service"}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
      end
      
    end
    
    context "nginxhttpTargetGroup" do
      let(:resource) { template["Resources"]["nginxhttpTargetGroup"] }

      it "is of type AWS::ElasticLoadBalancingV2::TargetGroup" do
          expect(resource["Type"]).to eq("AWS::ElasticLoadBalancingV2::TargetGroup")
      end
      
      it "to have property Port" do
          expect(resource["Properties"]["Port"]).to eq(80)
      end
      
      it "to have property Protocol" do
          expect(resource["Properties"]["Protocol"]).to eq("HTTP")
      end
      
      it "to have property VpcId" do
          expect(resource["Properties"]["VpcId"]).to eq({"Ref"=>"VPCId"})
      end
      
      it "to have property HealthCheckPath" do
          expect(resource["Properties"]["HealthCheckPath"]).to eq("/")
      end
      
      it "to have property Matcher" do
          expect(resource["Properties"]["Matcher"]).to eq({"HttpCode"=>200})
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Name", "Value"=>"ecs-service"}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
      end
      
    end
    
    context "webhttp" do
      let(:resource) { template["Resources"]["webhttp"] }

      it "is of type AWS::ElasticLoadBalancingV2::ListenerRule" do
          expect(resource["Type"]).to eq("AWS::ElasticLoadBalancingV2::ListenerRule")
      end
      
      it "to have property Actions" do
          expect(resource["Properties"]["Actions"]).to eq({"Fn::If"=>["EnableCognito", [{"Type"=>"forward", "Order"=>5000, "TargetGroupArn"=>{"Ref"=>"nginxhttpTargetGroup"}}, {"Type"=>"authenticate-cognito", "Order"=>1, "AuthenticateCognitoConfig"=>{"UserPoolArn"=>{"Ref"=>"UserPoolId"}, "UserPoolClientId"=>{"Ref"=>"UserPoolClientId"}, "UserPoolDomain"=>{"Ref"=>"UserPoolDomainName"}}}], [{"Type"=>"forward", "Order"=>5000, "TargetGroupArn"=>{"Ref"=>"nginxhttpTargetGroup"}}]]})
      end
      
      it "to have property Conditions" do
          expect(resource["Properties"]["Conditions"]).to eq([{"Field"=>"host-header", "Values"=>["www.*"]}])
      end
      
      it "to have property ListenerArn" do
          expect(resource["Properties"]["ListenerArn"]).to eq({"Ref"=>"httpListener"})
      end
      
      it "to have property Priority" do
          expect(resource["Properties"]["Priority"]).to eq(100)
      end
      
    end
    
    context "nginxhttpsTargetGroup" do
      let(:resource) { template["Resources"]["nginxhttpsTargetGroup"] }

      it "is of type AWS::ElasticLoadBalancingV2::TargetGroup" do
          expect(resource["Type"]).to eq("AWS::ElasticLoadBalancingV2::TargetGroup")
      end
      
      it "to have property Port" do
          expect(resource["Properties"]["Port"]).to eq(443)
      end
      
      it "to have property Protocol" do
          expect(resource["Properties"]["Protocol"]).to eq("HTTPS")
      end
      
      it "to have property VpcId" do
          expect(resource["Properties"]["VpcId"]).to eq({"Ref"=>"VPCId"})
      end
      
      it "to have property HealthCheckPath" do
          expect(resource["Properties"]["HealthCheckPath"]).to eq("/")
      end
      
      it "to have property Matcher" do
          expect(resource["Properties"]["Matcher"]).to eq({"HttpCode"=>200})
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Name", "Value"=>"ecs-service"}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
      end
      
    end
    
    context "webhttps" do
      let(:resource) { template["Resources"]["webhttps"] }

      it "is of type AWS::ElasticLoadBalancingV2::ListenerRule" do
          expect(resource["Type"]).to eq("AWS::ElasticLoadBalancingV2::ListenerRule")
      end
      
      it "to have property Actions" do
          expect(resource["Properties"]["Actions"]).to eq({"Fn::If"=>["EnableCognito", [{"Type"=>"forward", "Order"=>5000, "TargetGroupArn"=>{"Ref"=>"nginxhttpsTargetGroup"}}, {"Type"=>"authenticate-cognito", "Order"=>1, "AuthenticateCognitoConfig"=>{"UserPoolArn"=>{"Ref"=>"UserPoolId"}, "UserPoolClientId"=>{"Ref"=>"UserPoolClientId"}, "UserPoolDomain"=>{"Ref"=>"UserPoolDomainName"}}}], [{"Type"=>"forward", "Order"=>5000, "TargetGroupArn"=>{"Ref"=>"nginxhttpsTargetGroup"}}]]})
      end
      
      it "to have property Conditions" do
          expect(resource["Properties"]["Conditions"]).to eq([{"Field"=>"host-header", "Values"=>["www.*"]}])
      end
      
      it "to have property ListenerArn" do
          expect(resource["Properties"]["ListenerArn"]).to eq({"Ref"=>"httpsListener"})
      end
      
      it "to have property Priority" do
          expect(resource["Properties"]["Priority"]).to eq(100)
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
          expect(resource["Properties"]["DesiredCount"]).to eq({"Fn::If"=>["NoDesiredCount", {"Ref"=>"AWS::NoValue"}, {"Ref"=>"DesiredCount"}]})
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
          expect(resource["Properties"]["LoadBalancers"]).to eq([{"ContainerName"=>"nginx", "ContainerPort"=>80, "TargetGroupArn"=>{"Ref"=>"nginxhttpTargetGroup"}}, {"ContainerName"=>"nginx", "ContainerPort"=>443, "TargetGroupArn"=>{"Ref"=>"nginxhttpsTargetGroup"}}])
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Name", "Value"=>"ecs-service"}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
      end
      
    end
    
  end

end