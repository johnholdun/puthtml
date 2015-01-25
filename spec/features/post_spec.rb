require 'spec_helper'

RSpec.describe 'post upload actions', type: :feature do
  before :each do
    # Bypass OAuth and return to home page
    visit '/auth/backdoor/jeeplanger'

    @file_contents = '<h1>This is my file</h1>'

    @file = Tempfile.new 'html'
    @file.write @file_contents
    @file.close
  end

  after :each do
    @file.unlink
  end

  it 'uploads a post without a path' do
    attach_file 'post[file]', @file.path
    click_button 'Put HTML'

    # Then we are redirected to our file...

    expect(page.body).to eq(@file_contents)
  end

  it 'uploads a post with a path' do
    post_path = 'super-cool'

    attach_file 'post[file]', @file.path
    fill_in 'post[path]', with: post_path

    click_button 'Put HTML'

    # Then we are redirected to our file...

    uri = URI.parse current_url

    expect(uri.path).to eq("/jeeplanger/#{ post_path }.html")
    expect(page.body).to eq(@file_contents)
  end

  it 'deletes a post' do
    post_path = 'super-cool-to-delete'

    attach_file 'post[file]', @file.path
    fill_in 'post[path]', with: post_path

    click_button 'Put HTML'

    visit '/'

    button_selector = "form.delete[action='/jeeplanger/#{ post_path }.html'] button"

    button = first button_selector

    button.click

    expect(first button_selector).to be_nil
  end
end

RSpec.describe 'post actions', type: :feature do
  it 'updates view counts'

  it 'copies a post'
end
