require 'rubygems'
require 'bundler'

Bundler.require
use Rack::Session::Cookie, secret: ENV['COOKIE_SECRET']
use Rack::Logger

require './puthtml'
run PutHTML
