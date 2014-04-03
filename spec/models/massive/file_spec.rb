require "spec_helper"

describe Massive::File do
  let(:processor) { double(FileProcessor::CSV) }
  let(:process)   { Massive::FileProcess.new }

  let(:url)       { 'http://someurl.com' }
  let(:encoding)  { nil }
  let(:col_sep)   { nil }

  let(:expected_options) do
    {
      headers: true,
      encoding: encoding,
      col_sep: col_sep
    }
  end

  subject(:file)  { process.file = Massive::File.new(url: url, encoding: encoding, col_sep: col_sep) }

  before { FileProcessor::CSV.stub(:new).with(file.url, expected_options).and_return(processor) }

  describe "#processor" do
    it "creates a new instance of the CSV file processor, enabling headers but without encoding and separator" do
      file.processor.should eq(processor)
    end

    context "when encoding and col_sep are defined" do
      let(:encoding)  { 'iso-8859-1' }
      let(:col_sep)   { ';' }

      it "creates a new instance of the CSV file processor, passing encoding and col_sep" do
        file.processor.should eq(processor)
      end
    end

    describe "when specifying that the file should have no headers" do
      subject(:file)  { process.file = Massive::File.new(url: url, encoding: encoding, col_sep: col_sep, use_headers: false) }

      let(:expected_options) do
        {
          headers: false,
          encoding: encoding,
          col_sep: col_sep
        }
      end

      it "creates a new instance of the CSV file processor, passing encoding and col_sep" do
        file.processor.should eq(processor)
      end
    end

    describe "when using Fog" do
      let(:filename) { 'my-file.txt' }
      let(:fog_connection) { double(Fog::Storage) }
      let(:fog_directory) { double('Directory') }
      let(:fog_file) { double('File') }
      let(:authenticated_url) { 'http://my-auth.url.com' }

      subject(:file)  { Massive::File.new(filename: filename, encoding: encoding, col_sep: col_sep) }

      before do
        Massive.fog_credentials = { provider: 'AWS', aws_access_key_id: 'some-key', aws_secret_access_key: 'some-secret' }
        Massive.fog_authenticated_url_expiration = 1.hour
        Massive.fog_directory = 'my-bucket'

        Fog::Storage.stub(:new).with(Massive.fog_credentials).and_return(fog_connection)
        fog_connection.stub_chain(:directories, :get).with(Massive.fog_directory).and_return(fog_directory)
        fog_directory.stub_chain(:files, :get).with(filename).and_return(fog_file)
        fog_file.stub(:url).with(Time.current.to_i + Massive.fog_authenticated_url_expiration).and_return(authenticated_url)
      end

      it "creates a new instance of the CSV file processor, pointing its URL to the authenticated fog url" do
        FileProcessor::CSV.should_receive(:new).with(authenticated_url, expected_options).and_return(processor)
        file.processor.should eq(processor)
      end
    end
  end

  describe "#gather_info!" do
    let(:detected_encoding) { 'iso-8859-1' }
    let(:detected_col_sep)  { ';' }
    let(:total_count)       { 1000 }
    let(:headers)           { ['some header', 'other header' ] }

    let(:processor) do
      double(FileProcessor::CSV, {
        detected_encoding: detected_encoding,
        col_sep:           detected_col_sep,
        total_count:       total_count,
        shift:             true,
        headers:           headers
      })
    end

    let(:row) do
      double(CSV::Row, fields: ['some value', 'other value'])
    end

    before do
      processor.stub(:process_range)
               .with(limit: 3)
               .and_yield(row)
               .and_yield(row)
               .and_yield(row)
    end

    it "detects the file encoding, and persists it" do
      file.gather_info!
      file.reload.encoding.should eq(detected_encoding)
    end

    it "detects the column separator, and persists it" do
      file.gather_info!
      file.reload.col_sep.should eq(detected_col_sep)
    end

    it "stores the total count, and persists it" do
      file.gather_info!
      file.reload.total_count.should eq(total_count)
    end

    it "stores the headers, and persists it" do
      file.gather_info!
      file.reload.headers.should eq(headers)
    end

    it "stores a sample data with 3 rows data, and persists it" do
      file.gather_info!
      file.reload.sample_data.should eq([row.fields, row.fields, row.fields])
    end

    context "when file has no headers" do
      subject(:file) { process.file = Massive::File.new(url: url, encoding: encoding, col_sep: col_sep, use_headers: false) }

      let(:expected_options) do
        {
          headers: false,
          encoding: encoding,
          col_sep: col_sep
        }
      end

      let(:processor) do
        double(FileProcessor::CSV, {
          detected_encoding: encoding,
          col_sep:           col_sep,
          total_count:       3,
          shift:             true
        })
      end

      let(:row) { ['some value', 'other value'] }

      before do
        processor.stub(:process_range)
                 .with(limit: 3)
                 .and_yield(row)
                 .and_yield(row)
                 .and_yield(row)
      end

      it "do not store the headers" do
        file.gather_info!
        file.reload.headers.should be_blank
      end

      it "store raw row in the sample data" do
        file.gather_info!
        file.reload.sample_data.should eq [row, row, row]
      end
    end

    context "when file already has gathered info" do
      before do
        file.encoding = 'utf-8'
        file.col_sep = '|'
        file.total_count = 3000
        file.headers = ['some other headers']
        file.sample_data = [['some other values']]
      end

      it "detects the file encoding, and persists it" do
        file.gather_info!
        file.reload.encoding.should eq(detected_encoding)
      end

      it "detects the column separator, and persists it" do
        file.gather_info!
        file.reload.col_sep.should eq(detected_col_sep)
      end

      it "stores the total count, and persists it" do
        file.gather_info!
        file.reload.total_count.should eq(total_count)
      end

      it "stores the headers, and persists it" do
        file.gather_info!
        file.reload.headers.should eq(headers)
      end

      it "stores a sample data with 3 rows data, and persists it" do
        file.gather_info!
        file.reload.sample_data.should eq([row.fields, row.fields, row.fields])
      end
    end
  end
end
