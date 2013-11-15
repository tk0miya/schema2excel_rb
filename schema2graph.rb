#!/usr/bin/env ruby

require 'rubygems'
require 'yaml'
require 'schema'
require 'getpass'
require 'graphviz'
require 'getoptlong'
require 'singleton'

class Configuration
  include Singleton

  def [](key)
    (@options[key.to_s] || @options[key.to_sym])  rescue nil
  end

  def self.parse_options
    instance.parse_options
  end

  def parse_options
    @options = {}  if @options.nil?

    parser = GetoptLong.new
    parser.set_options(['--config',       '-f', GetoptLong::REQUIRED_ARGUMENT],
                       ['--related-only', '-r', GetoptLong::NO_ARGUMENT])
    parser.each_option do |name, arg|
      @options[name.sub(/^--/, '').gsub(/-/, '_').to_sym] = arg
    end

    unless @options[:config]
      @options[:config] = 'config.yaml'
    end

    self
  end

  def load_config(filename = nil)
    @options = {}  if @options.nil?

    filename ||= @options[:config]
    YAML.load_file(filename).each do |key, value|
      @options[key] = value
    end

    self
  end
end

def main(out_file)
  begin
    config = Configuration.parse_options
    config.load_config
    Schema.set_descriptions(config[:table_descriptions])
  rescue Errno::ENOENT
    STDERR.printf("configure file(%s) was not found. aborted.\n", config[:config])
    exit(1)
  end

  # DBMS からテーブル構造を取得
  schema = Schema.create(config[:database])
  authenticate(schema.password_prompt, config[:database]['password']) do |password|
    begin
      schema.connect(password)
    rescue DBI::DatabaseError
      nil
    end
  end
  schema.set_column_constraint


  # グラフの基本設定
  graph = GraphViz.new('G', :type => 'graph', :rankdir => 'RL')
  graph[:concentrate] = true
  graph.node[:shape] = 'record'

  # node/cluster 設定
  schema.table_groups.each_with_index do |group, index|
    if group[:tables].size > 1
      subgraph = graph.add_graph(sprintf("cluster%d", index))

      if group[:type] == 'hidden'
        subgraph[:style] = 'invis'
      end
    else
      subgraph = graph

      # 関連を持たないノードは出力しない
      if config[:related_only]
        table_name = group[:tables][0].name
        related_keys = Schema::KeyHolder.select do |key|
           key.referenced? && (key.table_name == table_name || key.ref_table_name == table_name)
        end

        if related_keys.empty?
          next
        end
      end
    end

    group[:tables].each do |table|
      label = sprintf('[[%s]]', table.name)
      keys = table.keys.select{|key| key.primary? || key.foreign?}
      keys.collect{|key| key.column}.uniq.each do |column|
        label += sprintf("|<%s> %s", column, column)
      end

      subgraph.add_node(table.name, 'label' => label)
    end
  end

  # edge 設定
  schema.tables.each do |table|
    unique_keys = table.keys.select{|key| (key.primary? || key.unique?) && !key.multiple?}.collect{|key| key.column}

    table.reference_keys.each do |key|
      if unique_keys.include?(key.column)
        tail = 'tee'
      else
        tail = 'crow'
      end

      node0 = sprintf('%s:%s', table.name, key.column)
      node1 = sprintf('%s:%s', key.ref_table_name, key.ref_column_name)
      graph.add_edge(node0, node1, 'arrowhead' => 'tee', 'arrowtail' => tail)
    end
  end

  graph.output(:png => out_file)
rescue
  printf("Error: %s\n", $!.message)
end


if $0 == __FILE__
  if ARGV.size < 1
    print "Usage: #{File.basename $0} dot_output_file\n"
    exit(1)
  end

  main(ARGV[0])
end
