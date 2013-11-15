#!/usr/bin/env ruby

require 'rubygems'
require "excel_output"
require "nkf"
require 'yaml'
require 'schema'
require 'getpass'
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
    parser.set_options(['--config',    '-f', GetoptLong::REQUIRED_ARGUMENT])
    parser.each_option do |name, arg|
      @options[name.sub(/^--/, '').to_sym] = arg
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
  headers = (0..10)

  begin
    config = Configuration.parse_options
    config.load_config
    Schema.set_descriptions(config[:table_descriptions])
  rescue Errno::ENOENT
    STDERR.printf("configure file(%s) was not found. aborted.\n", config[:config])
    exit(1)
  end

  # DBMS からテーブル構造を取得
  # TODO: view の情報を定義書に含める → 現在は普通のテーブルと同じコメントのみ
  #       どのテーブルのどのカラムを利用しているのか。
  schema = Schema.create(config[:database])
  authenticate(schema.password_prompt, config[:database]['password']) do |password|
    begin
      schema.connect(password)
    rescue DBI::DatabaseError
      nil
    end
  end
  schema.set_table_descriptions
  schema.set_column_descriptions

  # OWC 操作でXMLを出力
  OWC::Spreadsheet.open(config[:template]) do |book|
    # シートを複製
    sheet = book.Worksheets.Item(1)
    (schema.tables.size-1).times{ sheet.copy(nil,sheet) }
    # シートに書き込み
    schema.tables.each do |table|
      printf(STDERR, "exporting %s ...\n", table.name)

      sheet.extend(OWC::Spreadsheet::Worksheet) # extend methods
      # シート名
      sheet.name = table.name[0...31]
      # 位置指定書き込み[row,col] # TODO: セルの位置は設定に
      sheet[1,3] = config[:system_name]
      sheet[1,8] = config[:creator]
      sheet[3,3] = table.schema
      sheet[4,3] = table.fullname
      sheet[5,3] = table.name
      # 行複製＆書き込み
      writer = ExcelOutput::Writer.new(sheet, headers, 8, 2, table.columns.size) # TODO: セルの位置は設定に
      table.columns.each{|c| writer << c.to_a}
      # 次のシート
      sheet = sheet.Next
    end

    # XML出力
    xml = book.XMLData
    #xml = book.mergedXMLData # keep print style and others.. but not working..
    xml = NKF.nkf('--oc=UTF-8 -m0', xml) # don't convert XML to CP932!!
    File.open(out_file, 'wb') do |fout|
      fout.write(xml)
    end
  end
rescue
  printf("Error: %s\n", $!.message)
end


if $0 == __FILE__
  if ARGV.size < 1
    print "Usage: #{File.basename $0} excel_output_file\n"
    exit(1)
  end

  main(ARGV[0])
end

