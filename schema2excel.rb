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

  # DBMS ����e�[�u���\�����擾
  # TODO: view �̏����`���Ɋ܂߂� �� ���݂͕��ʂ̃e�[�u���Ɠ����R�����g�̂�
  #       �ǂ̃e�[�u���̂ǂ̃J�����𗘗p���Ă���̂��B
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

  # OWC �����XML���o��
  OWC::Spreadsheet.open(config[:template]) do |book|
    # �V�[�g�𕡐�
    sheet = book.Worksheets.Item(1)
    (schema.tables.size-1).times{ sheet.copy(nil,sheet) }
    # �V�[�g�ɏ�������
    schema.tables.each do |table|
      printf(STDERR, "exporting %s ...\n", table.name)

      sheet.extend(OWC::Spreadsheet::Worksheet) # extend methods
      # �V�[�g��
      sheet.name = table.name[0...31]
      # �ʒu�w�菑������[row,col] # TODO: �Z���̈ʒu�͐ݒ��
      sheet[1,3] = config[:system_name]
      sheet[1,8] = config[:creator]
      sheet[3,3] = table.schema
      sheet[4,3] = table.fullname
      sheet[5,3] = table.name
      # �s��������������
      writer = ExcelOutput::Writer.new(sheet, headers, 8, 2, table.columns.size) # TODO: �Z���̈ʒu�͐ݒ��
      table.columns.each{|c| writer << c.to_a}
      # ���̃V�[�g
      sheet = sheet.Next
    end

    # XML�o��
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

