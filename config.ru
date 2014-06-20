require 'rubygems'
require 'bundler'

Bundler.require
use Rack::Session::Cookie, secret: ENV['COOKIE_SECRET']
use Rack::Logger

use Rack::Subdomain, 'puthtml.dev', except: ['','www'], to: '/i'
use Rack::Subdomain, 'puthtml.com', except: ['','www'], to: '/i'

require './puthtml'
run PutHTML
