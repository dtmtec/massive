require "spec_helper"

describe Massive::ProcessSerializer do
  let(:process) { Massive::Process.new }
  subject(:serialized) { described_class.new(process).as_json(root: false) }

  it "serializes process id as string" do
    expect(serialized[:id]).to eq(process.id.to_s)
  end

  [:created_at, :updated_at].each do |field|
    it "serializes the #{field}" do
      process[field] = 1.minute.ago
      expect(serialized[field]).to eq(process[field])
    end
  end

  it "serializes the processed percentage" do
    allow(process).to receive(:processed_percentage).and_return(12)
    expect(serialized[:processed_percentage]).to eq(process.processed_percentage)
  end

  context "when it is completed" do
    before { allow(process).to receive(:completed?).and_return(true) }

    it "serializes completed" do
      expect(serialized[:completed]).to be_truthy
    end
  end

  context "when it is not completed" do
    before { allow(process).to receive(:completed?).and_return(false) }

    it "serializes completed" do
      expect(serialized[:completed]).to be_falsy
    end
  end

  context "when it does not respond to file" do
    it "does not serializes file" do
      expect(serialized[:file]).to be_blank
    end
  end

  context "when it responds to file" do
    let(:process) { Massive::FileProcess.new }

    it "serializes file" do
      expect(serialized[:file]).to be_present
    end
  end
end
