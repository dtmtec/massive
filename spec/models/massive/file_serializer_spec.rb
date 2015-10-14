require "spec_helper"

describe Massive::FileSerializer do
  let(:headers) { ['name', 'description', 'price'] }
  let(:sample_data) { [['Some name', 'Some desc', 1234], ['Other name', 'Other desc', 5678]] }
  let(:file) { Massive::File.new(url: 'http://some.url.com', encoding: 'utf8', col_sep: ';', total_count: 1234, use_headers: true, headers: headers, sample_data: sample_data, file_size: 12345) }
  subject(:serialized) { described_class.new(file).as_json(root: false) }

  it "serializes file id as string" do
    expect(serialized[:id]).to eq(file.id.to_s)
  end

  it "serializes url" do
    expect(serialized[:url]).to eq(file.url)
  end

  it "serializes encoding" do
    expect(serialized[:encoding]).to eq(file.encoding)
  end

  it "serializes col_sep" do
    expect(serialized[:col_sep]).to eq(file.col_sep)
  end

  it "serializes total_count" do
    expect(serialized[:total_count]).to eq(file.total_count)
  end

  it "serializes use_headers" do
    expect(serialized[:use_headers]).to eq(file.use_headers)
  end

  it "serializes headers" do
    expect(serialized[:headers]).to eq(file.headers)
  end

  it "serializes sample_data" do
    expect(serialized[:sample_data]).to eq(file.sample_data)
  end

  it "serializes file_size" do
    expect(serialized[:file_size]).to eq(file.file_size)
  end
end
