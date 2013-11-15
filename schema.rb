#!/usr/bin/ruby

require 'rubygems'
gem 'dbi'

require 'csv'
require 'dbi'

class Schema
  def self.create(config)
    driver = config['driver'].downcase
    case driver
      when 'mysql'
        require 'drivers/mysql'
        MySQLSchema.new(config)
      when 'pg'
        require 'drivers/pg'
        PgSchema.new(config)
      when 'odbc'
        require 'drivers/odbc'
        ODBCSchema.new(config)
      else
        self.new(config)
    end
  end

  def initialize(config)
    @config = config
  end

  def password_prompt
    sprintf('%s@%s/%s', @config['username'], @config['hostname'], @config['database'])
  end

  def dsn(password)
    sprintf('dbi:%s:%s:%s', @config['driver'], @config['database'], @config['hostname'])
  end

  def connect(password)
    @cn = DBI.connect(self.dsn(password), @config['username'], password)
  end

  def self.ignore_table?(table_name)
    ignores = Configuration.instance[:ignore_tables] || []

    ignores.any? do |pattern|
      if /^re:(.*)/.match(pattern)
        Regexp.compile($1).match(table_name)
      else
        table_name == pattern.to_s
      end
    end
  end

  def driver
    @config['driver'].downcase
  end

  def table_schema
    @config['schema'] || @config['owner'] || @config['database']
  end

  def table_names
    @cn.tables.delete_if {|t| Schema.ignore_table?(t)}
  end

  def tables
    unless @tables
      @tables = self.table_names.collect do |table_name|
        query = sprintf("SELECT * FROM information_schema.Columns " +
                        "WHERE TABLE_SCHEMA = '%s' AND TABLE_NAME = '%s'", self.table_schema, table_name)
        rs = @cn.execute(query)
        table = Schema::Table.new(self.table_schema, table_name, rs.fetch_all.collect{|r| r.to_h})
        rs.finish

        table
      end
    end

    @tables
  end

  def table_groups
    tables = self.tables.dup
    table_groups = []
    group_config = Configuration.instance[:table_groups] || []
    group_config.each do |attr|
      group = {:tables => []}
      group[:type] = attr['type']  if attr['type']

      attr['tables'].each do |pattern|
        if /^re:(.*)/.match(pattern)
          re = Regexp.compile($1)
          group[:tables] += tables.select{|table| re.match(table.name)}
          tables.delete_if{|table| re.match(table.name)}
        else
          group[:tables] += tables.select{|table| pattern == table.name}
          tables.delete_if{|table| pattern == table.name}
        end
      end
      table_groups.push(group)  unless group[:tables].empty?
    end

    table_groups + tables.collect{|table| {:tables => [table]}}
  end

  def set_table_descriptions
  end

  def set_column_descriptions
  end

  def set_column_constraint
  end

  def self.set_descriptions(descriptions)
    descriptions.each do |name, description|
      self.set_description(name, description)
    end
  end

  def self.set_description(name, description)
    class_variable_get(:@@descriptions)  rescue @@descriptions = Hash.new
    @@descriptions[name] = description
  end

  def self.get_description(name)
    @@descriptions[name] rescue nil
  end
end

class Schema
  module KeyHolder
    module_function

    def update(row)
      class_variable_get(:@@keys)  rescue @@keys = Array.new

      table_name = row['TABLE_NAME']
      name = row['CONSTRAINT_NAME']
      if key = self.find(table_name, name)
        key.update(row)
      else
        @@keys.push(Key.new(row))
      end
    end

    def find(table_name, name)
      @@keys.find{|k| !k.ignored? && k.table_name == table_name && k.name == name}
    rescue
      []
    end

    def select(name = nil)
      @@keys.select{|k| !k.ignored? && yield(k)}
    rescue
      []
    end
  end
end

class Schema
  class Key
    def initialize(attr)
      @attr = Hash.new
      attr.each do |k,v|
        @attr[k.upcase] = v
      end

      @columns = [@attr.delete('COLUMN_NAME')].compact
    end

    def update(attr)
      @columns.push(attr['COLUMN_NAME'])  if attr['COLUMN_NAME']
    end

    def name
      @attr['CONSTRAINT_NAME']
    end

    def table_name
      @attr['TABLE_NAME']
    end

    def ref_table_name
      @attr['REFERENCED_TABLE_NAME']
    end

    def ref_column_name
      @attr['REFERENCED_COLUMN_NAME']
    end

    def column
      raise StandardError.new('Call Schema::Key#column for multiple key')  if self.multiple?
      @columns[0] rescue nil
    end

    def columns
      @columns
    end

    def multiple?
      @columns.size > 1
    end

    def primary?
      @attr['CONSTRAINT_TYPE'] == 'PRIMARY KEY'
    end

    def unique?
      @attr['CONSTRAINT_TYPE'] == 'UNIQUE'
    end

    def foreign?
      @attr['CONSTRAINT_TYPE'] == 'FOREIGN KEY'
    end

    def referenced?
      @attr['REFERENCED_TABLE_NAME'] && @attr['REFERENCED_COLUMN_NAME']
    end

    def ignored?
      return false  if self.multiple?
      return true   if Schema.ignore_table?(self.ref_table_name)

      ignores = Configuration.instance[:ignore_key_columns] || []
      fullname = sprintf('%s.%s', self.table_name, self.column)

      ignores.any? do |pattern|
        if /^re:(.*)/.match(pattern)
          re = Regexp.compile($1)
          re.match(self.column) || re.match(fullname)
        else
          self.column == pattern.to_s || fullname == pattern.to_s
        end
      end
    end
  end
end

class Schema
  class Table
    def initialize(schema, name, columns)
      @schema = schema
      @name = name
      @columns = columns.collect{|c| Column.new(name, c)}
    end

    def fullname
      if Schema.get_description(@name)
        Schema.get_description(@name)
      else
        STDERR.printf("%s has no description.\n", @name)
        @name
      end
    end

    def schema
      @schema
    end

    def name
      @name
    end

    def columns
      @columns
    end

    def keys
      KeyHolder.select{|k| k.table_name == @name}
    end

    def reference_keys
      self.keys.select{|k| k.referenced? && k.table_name != k.ref_table_name}
    end

    def to_csv
      header = sprintf("## %s,%s\n", @name, self.fullname)
      header + @columns.collect{|c| c.to_csv}.join("\n")
    end
  end
end

class Schema
  class Table
    class Column
      def initialize(table_name, attr)
        @table_name = table_name
        @attr = Hash.new
        attr.each do |k,v|
          @attr[k.upcase] = v
        end
      end

      def column_comment
        Schema.get_description(self.longname) || @attr['COLUMN_COMMENT']
      end

      def fullname
        if (m = /^(.*?)(?:\(|（)(.*)(?:\)|）)\s*$/.match(self.column_comment))
          m[1]
        elsif (!self.column_comment.nil? and !self.column_comment.empty?)
          self.column_comment
        else
          @attr['COLUMN_NAME']
        end
      end

      def name
        @attr['COLUMN_NAME']
      end

      def longname
        sprintf("%s.%s", @table_name, self.name)
      end

      def type
        if @attr['COLUMN_TYPE']
          @attr['COLUMN_TYPE']
        else
          if @attr['CHARACTER_MAXIMUM_LENGTH'].kind_of?(Numeric)
            params = sprintf('(%d)', @attr['CHARACTER_MAXIMUM_LENGTH'])
          else
            params = ''
          end

          @attr['DATA_TYPE'].to_s + params
        end
      end

      def pkey?
        @attr['COLUMN_KEY'] == 'PRI'
      end

      def notnull?
        @attr['IS_NULLABLE'] != 'YES'
      end

      def default
        @attr['COLUMN_DEFAULT'] == 'NULL' ? @attr['COLUMN_DEFAULT'] : nil
      end

      def comment
        if (m = /^(.*?)(?:\(|（)(.*)(?:\)|）)\s*$/.match(self.column_comment))
          comment = m[2]
        else
          comment = ''
        end

        options = []
        if (@attr['COLLATION_NAME'] != 'utf8_general_ci')
          options.push(@attr['COLLATION_NAME'])
        end
        if (@attr.has_key?('EXTRA') && !@attr['EXTRA'].empty?)
          options.push(@attr['EXTRA'])
        end

        if (!options.compact.empty?)
          comment += sprintf('(%s)', options.compact.join(','))
        end

        comment
      end

      def keys
        KeyHolder.select{|k| k.table_name == @table_name && k.columns.include?(@name)}
      end

      def to_a
        pkey    = self.pkey?        ? 'TRUE' : 'FALSE'
        notnull = self.notnull?     ? 'TRUE' : 'FALSE'
        default = self.default.nil? ? 'NULL' : self.default

        [self.fullname, self.name, self.type, notnull, pkey, default, self.comment]
      end

      def to_csv
        CSV.generate_line(self.to_a)
      end
    end
  end
end

