require 'bundler/setup'
require 'sinatra/base'
require 'sinatra/reloader'

$:.push(File.dirname(__FILE__))
require 'db'

class Wiki < Sinatra::Base
  def self.startup
    @db = DB.new('http://localhost:9000', 'wiki', 'wiki')
    p @db
    p @db.load_schema
    run!
  end

  def self.db
    @db
  end

  def db
    self.class.db
  end

  configure :development do
    register Sinatra::Reloader
  end

  get '/' do
    redirect '/wiki'
  end

  get '/wiki' do
    page = db.find_page('index')
    haml :page, :locals => {:page => page}
  end

  post '/wiki' do
    db.update_page(params[:name], params[:text])
    redirect "/wiki/#{params[:name]}"
  end

  get %r'/wiki/([\w]+)' do |name|
    page = db.find_page(name)
    if page.nil?
      haml :form, :locals => {:name => name, :text => ''}
    else
      haml :page, :locals => {:page => page}
    end
  end

  get %r'/edit/([\w]+)' do |name|
    page = db.find_page(name)
    if page.nil?
      haml :form, :locals => {:name => name, :text => ''}
    else
      haml :form, :locals => {:name => page[:"page/name"], :text => page[:"page/text"]}
    end
  end


  startup if app_file == $0
end
