RSpec.describe 'user actions', type: :feature do
  before :each do
    # This signs us in, short-circuiting the OAuth routes, which we don't control and cannot test.
    # It also brings us back to the root path!
    visit '/auth/backdoor/jeeplanger'
  end

  it 'links to my profile' do
    click_link 'Visit your profile'
    expect(page).to have_content 'jeeplanger'
  end

  it 'resets my API key' do
    old_api_key = first('p.key')
    click_button 'Reset your API key'
    new_api_key = first('p.key')

    expect(old_api_key).not_to eq new_api_key
  end

  it 'signs me out' do
    click_button 'Sign out'
    expect(page).not_to have_content 'Visit your profile'
  end
end
