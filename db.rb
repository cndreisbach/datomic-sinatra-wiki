require 'edn'
require 'datomic/client'

class DB
  def self.id(*e)
    EDN.tagged_value('db/id', e)
  end

  SCHEMA = [
    { :"db/id" => id(:"db.part/db"),
      :"db/ident" => :"page/name",
      :"db/valueType" => :"db.type/string",
      :"db/cardinality" => :"db.cardinality/one",
      :"db/fulltext" => true,
      :"db/doc" => "The name of a page.",
      :"db/unique" => :"db.unique/value",
      :"db/index" => true,
      :"db.install/_attribute" => ":db.part/db"
    },
    {
      :"db/id" => id(:"db.part/db"),
      :"db/ident" => :"page/text",
      :"db/valueType" => :"db.type/string",
      :"db/cardinality" => :"db.cardinality/one",
      :"db/fulltext" => true,
      :"db/doc" => "The text of a page.",
      :"db.install/_attribute" => ":db.part/db"
    }
  ]

  attr_reader :dbname, :datomic

  def initialize(url, dbalias, dbname)
    @url = url
    @alias = dbalias
    @dbname = dbname
    @datomic = Datomic::Client.new @url, @alias
    @datomic.create_database(dbname)
    update_page('index', "Welcome to our example!")
  end

  def load_schema
    datomic.transact(dbname, SCHEMA)
  end

  def create_page(name, text)
    page_transact(DB.id(:"db.part/user"), name, text)
  end

  def update_page(name, text)
    page = find_page(name)
    dbid = page.nil? ? DB.id(:"db.part/user") : page[:"db/id"]
    page_transact(dbid, name, text)
  end

  def find_page(name)
    res = datomic.query(dbname,
                  [:find, ~"?p", :where, [~"?p", :"page/name", name]]).data
    if res.empty?
      nil
    else
      eid = res.first.first
      datomic.entity(dbname, eid).data
    end
  end

  def page_transact(dbid, name, text)
    begin
      data = {
        :"db/id" => dbid,
        :"page/name" => name,
        :"page/text" => text }
      datomic.transact(dbname, [data])
    rescue Exception => ex
      ex.message += "Bad data: #{data.inspect}"
      raise ex
    end
  end
end
