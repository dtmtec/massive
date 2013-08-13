require "spec_helper"

describe Massive::StepSerializer do
  let(:step) { Massive::Step.new }
  subject(:serialized) { described_class.new(step).as_json(root: false) }

  it "serializes the id as a string" do
    serialized[:id].should eq(step.id.to_s)
  end

  [ :created_at, :updated_at, :started_at, :finished_at, :failed_at ].each do |field|
    it "serializes the #{field}" do
      step[field] = 1.minute.ago
      serialized[field].should eq(step[field])
    end
  end

  it "serializes the last_error" do
    step.last_error = "Some error"
    serialized[:last_error].should eq(step.last_error)
  end

  [ :retries, :memory_consumption, :total_count ].each do |field|
    it "serializes the #{field}" do
      step[field] = 100
      serialized[field].should eq(step[field])
    end
  end

  [ :processed, :processed_percentage, :processing_time, :elapsed_time ].each do |field|
    it "serializes the #{field}" do
      step.stub(field).and_return(100)
      serialized[field].should eq(step.send(field))
    end
  end
end
