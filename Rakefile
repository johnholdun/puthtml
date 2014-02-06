require 'sinatra/asset_pipeline/task.rb'
require './puthtml'

Sinatra::AssetPipeline::Task.define! PutHTML

task :save_documents do |t|
  Document.save_all
end