require_relative '../../app/models/local_file_store'

RSpec.describe LocalFileStore do
  let(:filename) { 'a.txt' }
  let(:path) { Pathname.new '/tmp/test' }
  let(:contents) { 'hello world' }
  subject(:store) { LocalFileStore.new path }

  it 'sets' do
    expect(File).to receive(:write).with(path.join(filename), contents)
    store.set filename, contents
  end

  it 'gets' do
    expect(File).to receive(:exists?).with(path.join(filename)) { true }
    expect(File).to receive(:read).with(path.join(filename)) { contents }
    expect(store.get(filename)).to eq contents
  end

  it 'deletes' do
    expect(File).to receive(:exists?).with(path.join(filename)) { true }
    expect(File).to receive(:delete).with(path.join(filename)) { 1 }
    store.delete filename
  end
end
