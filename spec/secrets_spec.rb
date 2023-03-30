require 'yaml'

describe 'compiled component ecs-service' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/secrets.test.yaml")).to be_truthy
    end      
  end
  
  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/secrets/ecs-service.compiled.yaml") }
  
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
    
    context "TaskRole" do
      let(:resource) { template["Resources"]["TaskRole"] }

      it "is of type AWS::IAM::Role" do
          expect(resource["Type"]).to eq("AWS::IAM::Role")
      end
      
      it "to have property AssumeRolePolicyDocument" do
          expect(resource["Properties"]["AssumeRolePolicyDocument"]).to eq({"Version"=>"2012-10-17", "Statement"=>[{"Effect"=>"Allow", "Principal"=>{"Service"=>"ecs-tasks.amazonaws.com"}, "Action"=>"sts:AssumeRole"}, {"Effect"=>"Allow", "Principal"=>{"Service"=>"ssm.amazonaws.com"}, "Action"=>"sts:AssumeRole"}]})
      end
      
      it "to have property Path" do
          expect(resource["Properties"]["Path"]).to eq("/")
      end
      
      it "to have property Policies" do
          expect(resource["Properties"]["Policies"]).to eq([{"PolicyName"=>"s3", "PolicyDocument"=>{"Statement"=>[{"Sid"=>"s3", "Action"=>["s3:GetObject"], "Resource"=>["arn:aws:s3::::bucket/*"], "Effect"=>"Allow"}]}}])
      end
      
    end
    
    context "ExecutionRole" do
      let(:resource) { template["Resources"]["ExecutionRole"] }

      it "is of type AWS::IAM::Role" do
          expect(resource["Type"]).to eq("AWS::IAM::Role")
      end
      
      it "to have property AssumeRolePolicyDocument" do
          expect(resource["Properties"]["AssumeRolePolicyDocument"]).to eq({"Version"=>"2012-10-17", "Statement"=>[{"Effect"=>"Allow", "Principal"=>{"Service"=>"ecs-tasks.amazonaws.com"}, "Action"=>"sts:AssumeRole"}, {"Effect"=>"Allow", "Principal"=>{"Service"=>"ssm.amazonaws.com"}, "Action"=>"sts:AssumeRole"}]})
      end
      
      it "to have property Path" do
          expect(resource["Properties"]["Path"]).to eq("/")
      end
      
      it "to have property ManagedPolicyArns" do
          expect(resource["Properties"]["ManagedPolicyArns"]).to eq(["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"])
      end
      
      it "to have property Policies" do
          expect(resource["Properties"]["Policies"]).to eq([{"PolicyName"=>"ssm-secrets", "PolicyDocument"=>{"Statement"=>[{"Sid"=>"ssmsecrets", "Action"=>"ssm:GetParameters", "Resource"=>[{"Fn::Sub"=>"arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/nginx/${EnvironmentName}/api/key*"}, {"Fn::Sub"=>"arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/nginx/${EnvironmentName}/api/secret*"}], "Effect"=>"Allow"}]}}, {"PolicyName"=>"secretsmanager", "PolicyDocument"=>{"Statement"=>[{"Sid"=>"secretsmanager", "Action"=>"secretsmanager:GetSecretValue", "Resource"=>[{"Fn::Sub"=>"arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:/dont/use/accesskeys*"}, {"Fn::Sub"=>"arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:{\"Ref\"=>\"EnvironmentName\"}*"}], "Effect"=>"Allow"}]}}])
      end
      
    end
    
    context "Task" do
      let(:resource) { template["Resources"]["Task"] }

      it "is of type AWS::ECS::TaskDefinition" do
          expect(resource["Type"]).to eq("AWS::ECS::TaskDefinition")
      end
      
      it "to have property ContainerDefinitions" do
          expect(resource["Properties"]["ContainerDefinitions"]).to eq([{"Name"=>"nginx", "Image"=>{"Fn::Join"=>["", ["nginx/", "nginx", ":", "latest"]]}, "LogConfiguration"=>{"LogDriver"=>"awslogs", "Options"=>{"awslogs-group"=>{"Ref"=>"LogGroup"}, "awslogs-region"=>{"Ref"=>"AWS::Region"}, "awslogs-stream-prefix"=>"nginx"}}, "Secrets"=>[{"Name"=>"API_KEY", "ValueFrom"=>{"Fn::Sub"=>"arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/nginx/${EnvironmentName}/api/key"}}, {"Name"=>"API_SECRET", "ValueFrom"=>{"Fn::Sub"=>"arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/nginx/${EnvironmentName}/api/secret"}}, {"Name"=>"ACCESSKEY", "ValueFrom"=>"/dont/use/accesskeys"}, {"Name"=>"SECRETKEY", "ValueFrom"=>{"Fn::Sub"=>"arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:{\"Ref\"=>\"EnvironmentName\"}"}}]}])
      end
      
      it "to have property TaskRoleArn" do
          expect(resource["Properties"]["TaskRoleArn"]).to eq({"Ref"=>"TaskRole"})
      end
      
      it "to have property ExecutionRoleArn" do
          expect(resource["Properties"]["ExecutionRoleArn"]).to eq({"Ref"=>"ExecutionRole"})
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
          expect(resource["Properties"]["LoadBalancers"]).to eq([{"ContainerName"=>"nginx", "ContainerPort"=>80, "TargetGroupArn"=>{"Ref"=>"TargetGroup"}}])
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Name", "Value"=>"ecs-service"}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
      end
      
    end
    
  end

end