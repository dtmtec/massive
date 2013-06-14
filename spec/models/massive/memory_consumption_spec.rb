require "spec_helper"

shared_examples_for Massive::MemoryConsumption do
  let(:memory) { 123456 }
  let(:io) { mock(IO, gets: "    #{memory} ") }
  before { IO.stub(:popen).with("ps -o rss= -p #{Process.pid}").and_yield(io) }

  its(:current_memory_consumption) { should eq(memory) }

  context "and an error is raised" do
    let(:error) { StandardError.new('some error') }
    before { IO.stub(:popen).with("ps -o rss= -p #{Process.pid}").and_raise(error) }

    its(:current_memory_consumption) { should be_zero }
  end
end

describe Massive::Step do
  it_should_behave_like Massive::MemoryConsumption
end

describe Massive::Job do
  it_should_behave_like Massive::MemoryConsumption
end
