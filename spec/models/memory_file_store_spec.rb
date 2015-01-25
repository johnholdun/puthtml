require_relative '../../app/models/memory_file_store'

RSpec.describe MemoryFileStore do
  let(:filename) { 'some_file.txt' }
  let(:contents) { 'hello world!' }
  subject(:store) { MemoryFileStore.new }

  it 'sets' do
    # if this doesn't raise an error then we're good
    store.set filename, contents
  end

  it 'gets' do
    store.set filename, contents
    expect(store.get(filename)).to eq(contents)
  end

  it 'deletes' do
    store.set filename, contents
    store.delete filename
    expect(store.get(filename)).to be_nil
  end
end
