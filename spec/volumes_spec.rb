require 'yaml'

describe 'compiled component ecs-service' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/volumes.test.yaml")).to be_truthy
    end      
  end
  
  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/volumes/ecs-service.compiled.yaml") }
  
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
          expect(resource["Properties"]["ContainerDefinitions"]).to eq([{"Name"=>"sftp", "Image"=>{"Fn::Join"=>["", ["", "nginx", ":", "latest"]]}, "LogConfiguration"=>{"LogDriver"=>"awslogs", "Options"=>{"awslogs-group"=>{"Ref"=>"LogGroup"}, "awslogs-region"=>{"Ref"=>"AWS::Region"}, "awslogs-stream-prefix"=>"sftp"}}, "MountPoints"=>[{"ContainerPath"=>{"Fn::Sub"=>"/etc/${EnvironmentName}"}, "SourceVolume"=>{"Fn::Sub"=>"${EnvironmentName}"}, "ReadOnly"=>false}, {"ContainerPath"=>{"Fn::Sub"=>"/data"}, "SourceVolume"=>{"Fn::Sub"=>"${EnvironmentName}.mybucket"}, "ReadOnly"=>false}, {"ContainerPath"=>{"Fn::Sub"=>"/data"}, "SourceVolume"=>{"Fn::Sub"=>"${EnvironmentName}.mybucket-${AWS::Region}"}, "ReadOnly"=>false}, {"ContainerPath"=>"/data", "SourceVolume"=>{"Fn::Sub"=>"bucket-${EnvironmentName}-${AWS::Region}"}, "ReadOnly"=>false}], "PortMappings"=>[{"ContainerPort"=>80}], "Privileged"=>true}])
      end
      
      it "to have property Volumes" do
          expect(resource["Properties"]["Volumes"]).to eq([{"Name"=>{"Fn::Sub"=>"/data"}}, {"Name"=>{"Fn::Sub"=>"test"}, "Host"=>{"SourcePath"=>{"Fn::Sub"=>"/test"}}}, {"Name"=>{"Fn::Sub"=>"${EnvironmentName}"}, "Host"=>{"SourcePath"=>{"Fn::Sub"=>"/etc/${EnvironmentName}"}}}, {"Name"=>{"Fn::Sub"=>"${EnvironmentName}.mybucket"}, "DockerVolumeConfiguration"=>{"Driver"=>"rexray/s3fs", "Scope"=>"shared"}}, {"Name"=>{"Fn::Sub"=>"${EnvironmentName}-MyEFSMount"}, "EFSVolumeConfiguration"=>{"FilesystemId"=>"fs-12345", "RootDirectory"=>"/my/desired/path"}}])
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
    
    context "ServiceRegistry" do
      let(:resource) { template["Resources"]["ServiceRegistry"] }

      it "is of type AWS::ServiceDiscovery::Service" do
          expect(resource["Type"]).to eq("AWS::ServiceDiscovery::Service")
      end
      
      it "to have property NamespaceId" do
          expect(resource["Properties"]["NamespaceId"]).to eq({"Ref"=>"NamespaceId"})
      end
      
      it "to have property Name" do
          expect(resource["Properties"]["Name"]).to eq("ninx")
      end
      
      it "to have property DnsConfig" do
          expect(resource["Properties"]["DnsConfig"]).to eq({"DnsRecords"=>[{"TTL"=>60, "Type"=>"A"}], "RoutingPolicy"=>"WEIGHTED"})
      end
      
      it "to have property HealthCheckConfig" do
          expect(resource["Properties"]["HealthCheckConfig"]).to eq({"Type"=>"HTTP", "ResourcePath"=>"/healthcheck", "FailureThreshold"=>3})
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
          expect(resource["Properties"]["DesiredCount"]).to eq({"Fn::If" => ["NoDesiredCount", {"Ref"=>"AWS::NoValue"}, {"Ref"=>"DesiredCount"}]})
      end
      
      it "to have property DeploymentConfiguration" do
          expect(resource["Properties"]["DeploymentConfiguration"]).to eq({"MinimumHealthyPercent"=>{"Ref"=>"MinimumHealthyPercent"}, "MaximumPercent"=>{"Ref"=>"MaximumPercent"}})
      end
      
      it "to have property TaskDefinition" do
          expect(resource["Properties"]["TaskDefinition"]).to eq({"Ref"=>"Task"})
      end
      
      it "to have property ServiceRegistries" do
          expect(resource["Properties"]["ServiceRegistries"]).to eq([{"RegistryArn"=>{"Fn::GetAtt"=>["ServiceRegistry", "Arn"]}, "ContainerName"=>"nginx", "ContainerPort"=>80}])
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Name", "Value"=>"ecs-service"}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
      end
      
    end
    
  end

end