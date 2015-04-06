require "spec_helper"

describe Massive::FileSerializer do
  let(:headers) { ['name', 'description', 'price'] }
  let(:sample_data) { [['Some name', 'Some desc', 1234], ['Other name', 'Other desc', 5678]] }
  let(:file) { Massive::File.new(url: 'http://some.url.com', encoding: 'utf8', col_sep: ';', total_count: 1234, use_headers: true, headers: headers, sample_data: sample_data) }
  subject(:serialized) { described_class.new(file).as_json(root: false) }

  it "serializes file id as string" do
    serialized[:id].should eq(file.id.to_s)
  end

  it "serializes url" do
    serialized[:url].should eq(file.url)
  end

  it "serializes encoding" do
    serialized[:encoding].should eq(file.encoding)
  end

  it "serializes col_sep" do
    serialized[:col_sep].should eq(file.col_sep)
  end

  it "serializes total_count" do
    serialized[:total_count].should eq(file.total_count)
  end

  it "serializes use_headers" do
    serialized[:use_headers].should eq(file.use_headers)
  end

  it "serializes headers" do
    serialized[:headers].should eq(file.headers)
  end

  it "serializes sample_data" do
    serialized[:sample_data].should eq(file.sample_data)
  end
end
