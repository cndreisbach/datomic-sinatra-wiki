require 'bundler/setup'

require 'haml'
require 'sinatra/base'
require 'sinatra/content_for'
require 'sinatra/reloader'
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

    def space(text)
      text.gsub(/_/, ' ')
    end

    def history_url(name)
      "/history/#{underscore(name)}"
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
      haml :page, :locals => {:name => page[1], :text => page[2]}
    end
  end

  post '/wiki' do
    db.update_page(params[:name], params[:text])
    redirect page_url(params[:name])
  end

  get %r'/wiki/([\w]+)' do |name|
    name = space(name)
    page = db.find_page(name)
    if page.nil?
      haml :form, :locals => {:name => name, :text => ''}
    else
      haml :page, :locals => {:name => page[1], :text => page[2]}
    end
  end

  get %r'/edit/([\w]+)' do |name|
    name = space(name)
    page = db.find_page(name)
    if page.nil?
      haml :form, :locals => {:name => name, :text => ''}
    else
      haml :form, :locals => {:name => page[1], :text => page[2]}
    end
  end

  get %r'/history/([\w]+)' do |name|
    name = space(name)
    history = db.page_history(name)
    if history.empty?
      redirect page_url(name)
    else
      haml :history, :locals => {:name => name, :history => history}
    end
  end

  startup if app_file == $0
end
