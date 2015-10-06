require "spec_helper"

describe Massive::Authenticators::Filesystem do
  let(:filename) { 'some/path/my-filename.png' }
  subject(:authenticator) { described_class.new(filename) }

  before do
    # resetting storage config to the default one
    Massive.storage_config = {
      directory: 'massive',
      provider: Massive::Authenticators::Filesystem,
      key: nil,
      secret: nil,
      expiration: 1 * 60 * 60
    }
  end

  it "properly build url by joining the directory and the given filename" do
    expect(authenticator.url).to eq(::File.join(Massive.storage_config[:directory], filename))
  end

  context "when the filename is not defined" do
    let(:filename) { nil }

    it "returns nil" do
      expect(authenticator.url).to be_nil
    end
  end
end
