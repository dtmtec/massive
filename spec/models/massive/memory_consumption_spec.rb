require "spec_helper"

shared_examples_for Massive::MemoryConsumption do
  let(:memory) { 123456 }
  let(:io) { double(IO, gets: "    #{memory} ") }
  before { allow(IO).to receive(:popen).with("ps -o rss= -p #{Process.pid}").and_yield(io) }

  its(:current_memory_consumption) { is_expected.to eq(memory) }

  context "and an error is raised" do
    let(:error) { StandardError.new('some error') }
    before { allow(IO).to receive(:popen).with("ps -o rss= -p #{Process.pid}").and_raise(error) }

    its(:current_memory_consumption) { is_expected.to be_zero }
  end
end

describe Massive::Step do
  it_should_behave_like Massive::MemoryConsumption
end

describe Massive::Job do
  it_should_behave_like Massive::MemoryConsumption
end
