require 'yaml'

describe 'compiled component ecs-service' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/custom_loggroup.test.yaml")).to be_truthy
    end      
  end
  
  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/custom_loggroup/ecs-service.compiled.yaml") }
  
  context "Resource" do

    
    context "LogGroup" do
      let(:resource) { template["Resources"]["LogGroup"] }

      it "is of type AWS::Logs::LogGroup" do
          expect(resource["Type"]).to eq("AWS::Logs::LogGroup")
      end
      
      it "to have property LogGroupName" do
          expect(resource["Properties"]["LogGroupName"]).to eq("2021-logs-nginx")
      end
      
      it "to have property RetentionInDays" do
          expect(resource["Properties"]["RetentionInDays"]).to eq("7")
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
    
  end

end