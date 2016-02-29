require 'spec_helper'

RSpec.describe 'post upload actions', type: :feature do
  let(:username) { Faker::Internet.user_name nil, %w(_) }
  let!(:user) { User.create name: username, uid: SecureRandom.random_number(10_000).to_s }

  let(:html_file_contents) { '<h1>This is my file</h1>' }
  let(:html_file) {
    Tempfile.new(%w(test .html)).tap { |file|
      file.write html_file_contents
      file.close
    }
  }

  before :each do
    # Bypass OAuth and return to home page
    visit "/auth/backdoor/#{ username }"
  end

  after :each do
    html_file.unlink
  end

  it 'uploads an HTML page without a path' do
    attach_file 'post[file]', html_file.path
    click_button 'Put HTML'

    # Then we are redirected to our file...

    basename_without_extension = File.basename(html_file.path).sub /#{ File.extname html_file.path }$/, ''

    expect(current_url).to end_with(basename_without_extension)
    expect(page.body).to eq(html_file_contents)
  end

  it 'uploads a post with a path' do
    post_path = 'super-cool'

    attach_file 'post[file]', html_file.path
    fill_in 'post[path]', with: post_path

    click_button 'Put HTML'

    # Then we are redirected to our file...

    uri = URI.parse current_url

    expect(uri.path).to eq("/#{ File.join username, post_path }")
    expect(page.body).to eq(html_file_contents)
  end

  it 'deletes a post' do
    post_path = 'super-cool-to-delete'

    attach_file 'post[file]', html_file.path
    fill_in 'post[path]', with: post_path

    click_button 'Put HTML'

    visit '/'

    button_selector = "form.delete[action='/#{ username }/#{ post_path }'] button"

    button = first button_selector

    button.click

    expect(first button_selector).to be_nil
  end
end

RSpec.describe 'post actions', type: :feature do
  it 'copies a post'
end
