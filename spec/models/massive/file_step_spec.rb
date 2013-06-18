require "spec_helper"

describe Massive::FileStep do
  let(:process)  { Massive::FileProcess.new file_attributes: { url: 'http://someurl.com' } }
  subject(:step) { Massive::FileStep.new process: process }

  it "delegates file to process" do
    step.file.should eq(process.file)
  end

  context "when it is started!" do
    let(:file) { process.file }
    let(:total_count) { 1234 }

    before { file.total_count = total_count }

    it "calculates the total count, using the processor total count" do
      step.start!
      step.total_count.should eq(total_count)
    end
  end
end
