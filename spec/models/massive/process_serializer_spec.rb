require "spec_helper"

describe Massive::ProcessSerializer do
  let(:process) { Massive::Process.new }
  subject(:serialized) { described_class.new(process).as_json(root: false) }

  it "serializes process id as string" do
    serialized[:id].should eq(process.id.to_s)
  end

  [:created_at, :updated_at].each do |field|
    it "serializes the #{field}" do
      process[field] = 1.minute.ago
      serialized[field].should eq(process[field])
    end
  end

  it "serializes the processed percentage" do
    process.stub(:processed_percentage).and_return(12)
    serialized[:processed_percentage].should eq(process.processed_percentage)
  end

  context "when it is completed" do
    before { process.stub(:completed?).and_return(true) }

    it "serializes completed" do
      serialized[:completed].should be_true
    end
  end

  context "when it is not completed" do
    before { process.stub(:completed?).and_return(false) }

    it "serializes completed" do
      serialized[:completed].should be_false
    end
  end
end
