require "spec_helper"

describe Massive::FileStep do
  let(:process)  { Massive::FileProcess.new file_attributes: { url: 'http://someurl.com' } }
  subject(:step) { Massive::FileStep.new process: process }

  it "delegates file to process" do
    step.file.should eq(process.file)
  end

  context "when it is started!" do
    let(:file) { process.file }
    let(:calculated_total_count) { 1234 }

    before { file.stub_chain(:processor, :total_count).and_return(calculated_total_count) }

    it "calculates the total count, using the processor total count" do
      step.start!
      step.total_count.should eq(calculated_total_count)
    end
  end
end
