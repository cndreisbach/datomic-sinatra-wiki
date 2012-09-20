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

  INITIAL_PAGES = {
    'Home' => 'Welcome to our example wiki! To see the syntax, check out [[Wiki Syntax]].',
    'Wiki Syntax' => 'You can see the syntax at [https://wincent.com/misc/wikitext_cheatsheet the Wikitext cheatsheet].'
  }

  attr_reader :dbname, :datomic

  def initialize(url, dbalias, dbname)
    @url = url
    @alias = dbalias
    @dbname = dbname
    @datomic = Datomic::Client.new @url, @alias
    @datomic.create_database(dbname)
    load_schema
    INITIAL_PAGES.each do |name, text|
      update_page(name, text)
    end
  end

  def dbalias
    [@alias, dbname].join("/")
  end

  def load_schema
    datomic.transact(dbname, SCHEMA)
  end

  def create_page(name, text)
    page_transact(DB.id(:"db.part/user"), name, text)
  end

  def update_page(name, text)
    page = find_page(name)
    dbid = page.nil? ? DB.id(:"db.part/user") : page[0]
    page_transact(dbid, name, text)
  end

  def find_page(name)
    res = datomic.query(dbname, [
                          :find, ~"?id", ~"?name", ~"?text",
                          :in, ~"$db", ~"?name",
                          :where,
                          [~"$db", ~"?id", :"page/name", ~"?name"],
                          [~"$db", ~"?id", :"page/text", ~"?text"]],
                  :args => [{:"db/alias" => dbalias}, name])
    data = res.data
    if data.empty?
      nil
    else
      page = data.first
    end
  end

  def page_history(name)
    res = datomic.query(dbname, [
                          :find, ~"?v", ~"?time", ~"?tx",
                          :in, ~"$cur", ~"$hist", ~"?uniq-attr", ~"?uniq-val", ~"?hist-attr",
                          :where,
                          [~"$cur",  ~"?e",  ~"?uniq-attr", ~"?uniq-val"],
                          [~"$cur",  ~"?tx", ~":db/txInstant", ~"?time"],
                          [~"$hist", ~"?e",  ~"?hist-attr", ~"?v", ~"?tx", true]],
                  :args => [
                          {:"db/alias" => dbalias},
                          {:"db/alias" => dbalias, :history => true},
                          :"page/name",
                          name,
                          :"page/text"
                        ])

    res.data.sort { |a, b| b[1] <=> a[1] }
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
