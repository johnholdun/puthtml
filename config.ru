require 'rubygems'
require 'bundler'
require 'rack/csrf'

Bundler.require
use Rack::Session::Cookie, secret: ENV['COOKIE_SECRET']
use Rack::Logger

use Rack::Csrf, :raise => true, :check_only => ['POST:/']

if ENV['RACK_ENV'] == 'production'
  use Rack::Subdomain, 'puthtml.com', except: ['','www'], to: '/i.puthtml'
  content_host = 'i.puthtml.com'
  app_host = 'www.puthtml.com'
else
  use Rack::Subdomain, 'puthtml.dev', except: ['','www'], to: '/i.puthtml'
  content_host = 'i.puthtml.dev'
  app_host = 'www.puthtml.dev'
end

PUTHTML_CONTENT_HOST = content_host
PUTHTML_CONTENT_URL = "http://#{content_host}/"
PUTHTML_APP_HOST = app_host

require './puthtml'
run PutHTML
