require_relative '../../app/models/amazon_file_store'

RSpec.describe AmazonFileStore do
  let(:filename) { 'some_file.txt' }
  let(:contents) { 'hello world!' }
  subject(:store) { AmazonFileStore.new('test') }

  before do
    allow(store).to receive(:bucket_object) { double }
  end

  it 'sets' do
    expect(store).to receive(:write_to_bucket).with(filename, contents)
    store.set filename, contents
  end

  it 'gets' do
    expect(store).to receive(:read_from_bucket).with(filename) { contents }
    expect(store.get(filename)).to eq(contents)
  end

  it 'deletes' do
    expect(store).to receive(:delete_from_bucket).with(filename)
    store.delete filename
  end
end
