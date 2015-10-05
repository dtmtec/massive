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

  def stub_processor
    allow(FileProcessor::CSV).to receive(:new).with(file.url, expected_options).and_return(processor)
  end

  before { stub_processor }

  describe "#processor" do
    it "creates a new instance of the CSV file processor, enabling headers but without encoding and separator" do
      expect(file.processor).to eq(processor)
    end

    context "when encoding and col_sep are defined" do
      let(:encoding)  { 'iso-8859-1' }
      let(:col_sep)   { ';' }

      it "creates a new instance of the CSV file processor, passing encoding and col_sep" do
        expect(file.processor).to eq(processor)
      end
    end

    describe "when specifying that the file is_expected.to have no headers" do
      subject(:file)  { process.file = Massive::File.new(url: url, encoding: encoding, col_sep: col_sep, use_headers: false) }

      let(:expected_options) do
        {
          headers: false,
          encoding: encoding,
          col_sep: col_sep
        }
      end

      it "creates a new instance of the CSV file processor, passing encoding and col_sep" do
        expect(file.processor).to eq(processor)
      end
    end

    describe "when passing a filename" do
      let(:filename) { 'my/path/my-file.txt' }
      let(:url) { 'http://my-auth.url.com' }
      let(:provider) { double(Massive::Authenticators::S3, url: url) }

      subject(:file) { Massive::File.new(filename: filename, encoding: encoding, col_sep: col_sep) }

      def stub_processor
        allow(Massive.storage_config[:provider]).to receive(:new).with(filename).and_return(provider)
        allow(FileProcessor::CSV).to receive(:new).with(file.url, expected_options).and_return(processor)
      end

      it "creates a new instance of the CSV file processor, pointing its URL to the authenticator provider url" do
        expect(FileProcessor::CSV).to receive(:new).with(url, expected_options).and_return(processor)
        expect(file.processor).to eq(processor)
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
      allow(processor).to receive(:process_range)
               .with(limit: 3)
               .and_yield(row)
               .and_yield(row)
               .and_yield(row)
    end

    it "detects the file encoding, and persists it" do
      file.gather_info!
      expect(file.reload.encoding).to eq(detected_encoding)
    end

    it "detects the column separator, and persists it" do
      file.gather_info!
      expect(file.reload.col_sep).to eq(detected_col_sep)
    end

    it "stores the total count, and persists it" do
      file.gather_info!
      expect(file.reload.total_count).to eq(total_count)
    end

    it "stores the headers, and persists it" do
      file.gather_info!
      expect(file.reload.headers).to eq(headers)
    end

    it "stores a sample data with 3 rows data, and persists it" do
      file.gather_info!
      expect(file.reload.sample_data).to eq([row.fields, row.fields, row.fields])
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
        allow(processor).to receive(:process_range)
                 .with(limit: 3)
                 .and_yield(row)
                 .and_yield(row)
                 .and_yield(row)
      end

      it "do not store the headers" do
        file.gather_info!
        expect(file.reload.headers).to be_blank
      end

      it "store raw row in the sample data" do
        file.gather_info!
        expect(file.reload.sample_data).to eq [row, row, row]
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
        expect(file.reload.encoding).to eq(detected_encoding)
      end

      it "detects the column separator, and persists it" do
        file.gather_info!
        expect(file.reload.col_sep).to eq(detected_col_sep)
      end

      it "stores the total count, and persists it" do
        file.gather_info!
        expect(file.reload.total_count).to eq(total_count)
      end

      it "stores the headers, and persists it" do
        file.gather_info!
        expect(file.reload.headers).to eq(headers)
      end

      it "stores a sample data with 3 rows data, and persists it" do
        file.gather_info!
        expect(file.reload.sample_data).to eq([row.fields, row.fields, row.fields])
      end
    end
  end

  describe "#has_info?" do
    context "when file already has gathered info" do
      before do
        file.encoding = 'utf-8'
        file.col_sep = '|'
        file.total_count = 3000
      end

      its(:has_info?) { is_expected.to be_truthy }
    end

    context "when file has not gathered info" do
      before do
        file.encoding = nil
        file.col_sep = nil
        file.total_count = nil
      end

      its(:has_info?) { is_expected.to be_falsy }
    end
  end
end
