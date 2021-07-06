require 'yaml'

describe 'compiled component ecs-service' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/security_group.test.yaml")).to be_truthy
    end      
  end
  
  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/security_group/ecs-service.compiled.yaml") }
  
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
      
      it "to have property Cpu" do
          expect(resource["Properties"]["Cpu"]).to eq(1024)
      end
      
      it "to have property Memory" do
          expect(resource["Properties"]["Memory"]).to eq(2048)
      end
      
      it "to have property NetworkMode" do
          expect(resource["Properties"]["NetworkMode"]).to eq("awsvpc")
      end
      
      it "to have property RequiresCompatibilities" do
          expect(resource["Properties"]["RequiresCompatibilities"]).to eq({"Fn::If"=>["IsFargate", ["FARGATE"], ["EC2"]]})
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Name", "Value"=>"ecs-service"}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
      end
      
    end
    
    context "ServiceSecurityGroup" do
      let(:resource) { template["Resources"]["ServiceSecurityGroup"] }

      it "is of type AWS::EC2::SecurityGroup" do
          expect(resource["Type"]).to eq("AWS::EC2::SecurityGroup")
      end
      
      it "to have property VpcId" do
          expect(resource["Properties"]["VpcId"]).to eq({"Ref"=>"VPCId"})
      end
      
      it "to have property GroupDescription" do
          expect(resource["Properties"]["GroupDescription"]).to eq("ecs-service ECS service")
      end
      
      it "to have property SecurityGroupIngress" do
          expect(resource["Properties"]["SecurityGroupIngress"]).to eq([])
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Name", "Value"=>"ecs-service"}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
      end
      
    end
    
    context "Service" do
      let(:resource) { template["Resources"]["Service"] }

      it "is of type AWS::ECS::Service" do
          expect(resource["Type"]).to eq("AWS::ECS::Service")
      end
      
      it "to have property LaunchType" do
          expect(resource["Properties"]["LaunchType"]).to eq({"Fn::If"=>["IsEmptyLaunchType", {"Ref"=>"AWS::NoValue"}, {"Fn::If"=>["IsFargate", "FARGATE", "EC2"]}]})
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
      
      it "to have property LoadBalancers" do
          expect(resource["Properties"]["LoadBalancers"]).to eq([{"ContainerName"=>"nginx", "ContainerPort"=>80, "TargetGroupArn"=>{"Ref"=>"TargetGroup"}}])
      end
      
      it "to have property NetworkConfiguration" do
          expect(resource["Properties"]["NetworkConfiguration"]).to eq({"AwsvpcConfiguration"=>{"AssignPublicIp"=>"DISABLED", "SecurityGroups"=>[{"Ref"=>"ServiceSecurityGroup"}], "Subnets"=>{"Ref"=>"SubnetIds"}}})
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Name", "Value"=>"ecs-service"}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
      end
      
    end
    
  end

end