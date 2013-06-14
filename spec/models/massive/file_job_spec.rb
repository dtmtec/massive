require "spec_helper"

describe Massive::FileJob do
  let(:process)  { Massive::FileProcess.new file_attributes: { url: 'http://someurl.com' } }
  let(:step)     { Massive::FileStep.new process: process }
  let(:job)      { Massive::FileJob.new step: step, offset: 1000, limit: 300 }

  it "delegates file to step" do
    step.file.should eq(step.file)
  end

  describe "when running through each item" do
    let(:file) { process.file }
    let(:block) { Proc.new { } }

    it "yields the process range of the file processor, with its offset and limit" do
      file.stub_chain(:processor, :process_range)
          .with({ offset: job.offset, limit: job.limit })
          .and_yield(block)

      expect { |block| job.each_item(&block) }.to yield_control(&block)
    end
  end
end
