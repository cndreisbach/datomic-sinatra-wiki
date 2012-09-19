require 'bundler/setup'
require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'wikitext'

$:.push(File.dirname(__FILE__))
require 'db'

class Wiki < Sinatra::Base
  DBCONFIG = ['http://localhost:9000', 'example', 'wiki']
  helpers do
    def dburl
      "#{DBCONFIG[0]}/data/#{DBCONFIG[1]}/#{DBCONFIG[2]}/-/"
    end

    def wikify(text)
      Wikitext::Parser.new.parse(text, space_to_underscore: true)
    end

    def underscore(text)
      text.gsub(/\s/, '_')
    end

    def page_url(name)
      "/wiki/#{underscore(name)}"
    end

    def edit_url(name)
      "/edit/#{underscore(name)}"
    end

  end

  helpers Sinatra::ContentFor

  def self.startup
    @db = DB.new(*DBCONFIG)
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
    name = 'Home'
    page = db.find_page(name)
    if page.nil?
      haml :form, :locals => {:name => name, :text => ''}
    else
      haml :page, :locals => {:name => page[:"page/name"], :text => page[:"page/text"]}
    end
  end

  post '/wiki' do
    db.update_page(params[:name], params[:text])
    redirect page_url(params[:name])
  end

  get %r'/wiki/([\w]+)' do |name|
    name.gsub!(/_/, ' ')
    page = db.find_page(name)
    if page.nil?
      haml :form, :locals => {:name => name, :text => ''}
    else
      haml :page, :locals => {:name => page[:"page/name"], :text => page[:"page/text"]}
    end
  end

  get %r'/edit/([\w]+)' do |name|
    name.gsub!(/_/, ' ')
    page = db.find_page(name)
    if page.nil?
      haml :form, :locals => {:name => name, :text => ''}
    else
      haml :form, :locals => {:name => page[:"page/name"], :text => page[:"page/text"]}
    end
  end

  startup if app_file == $0
end
