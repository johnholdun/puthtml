require 'rubygems'
require 'bundler'

Bundler.require
use Rack::Session::Cookie, secret: ENV['COOKIE_SECRET']
use Rack::Logger

if ENV['RACK_ENV'] == 'production'
  use Rack::Subdomain, 'puthtml.com', except: ['','www'], to: '/i.puthtml.com'
  PUTHTML_CONTENT_URL = 'http://i.puthtml.com/'
  PUTHTML_APP_URL= 'http://www.puthtml.com/'
else
  use Rack::Subdomain, 'puthtml.dev', except: ['','www'], to: '/i.puthtml.com'
  PUTHTML_CONTENT_URL = 'http://i.puthtml.dev/'
  PUTHTML_APP_URL = 'http://www.puthtml.dev/'
end

require './puthtml'
run PutHTML
