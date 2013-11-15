begin
  require 'owc'
rescue MissingSourceFile # win32 以外のプラットフォームでは owc モジュールで require している win32ole が存在しない
end

TEMPLATES = {
  'checklist_loanactions' => {:row => 13, :col => 1},
}

module ExcelOutput
  class Writer
    def initialize(sheet, headers, offset_row = 2, offset_col = 1, lines = 0)
      # setup header
      #headers.each_with_index do |h,x|
      #  sheet[offset_row,offset_col+x] = h
      #end
      @headers = headers
      @sheet = sheet
      @offset_row = offset_row
      @offset_col = offset_col

      # insert では結合セルに対応できないのでコピー
      if lines > 1
        y = @offset_row + 1
        copy_from = @sheet.Range("#{@offset_row}:#{@offset_row}")
        @sheet.Range("#{y}:#{y + lines - 2}").insert
        copy_to = @sheet.Range("#{y}:#{y + lines - 2}")
        copy_from.copy(copy_to) rescue nil
      end
    end

    def << row
      # set columns data
      y = @offset_row
      x = @offset_col
      @headers.each do |column_name|
        @sheet.Cells.Item(y, x).Interior.Color = row.color if row.respond_to?(:color)
        @sheet[y, x] = row[column_name].to_s if column_name
        x = @sheet.next_col(y, x)
      end
      @offset_row += 1
    end
  end

  def self.make_tempname(prefix)
    tempfile = Tempfile.open(prefix)
    tempfile.close(false) # close and not delete.
    tempfile.path
  end

  # :key_name = 'template filename' or 'key_name for TEMPLATES'
  # :headers = cols headers
  # :rows = rows list / nil (need block)
  # :count = rows.count / 0
  # :usefile = true: return saved file's path / false: return XML data (default)
  #
  # using example:
  #   path = ::ExcelOutput::output('uesr_template',
  #                                User.column_names,
  #                                :rows => User.all,
  #                                :usefile => true)
  #   send_file(path,
  #             :filename => Time.now.strftime('export_%Y%m%d_%H%M%S.xml'),
  #             :disposition => 'attachment',
  #             :type => 'application/vnd.ms-excel'
  #   )
  #
  def self.output(key_name, headers, options={}, &block)
    offset_row = 1
    offset_col = 1
    template_name = key_name

    tmpl = TEMPLATES[key_name]
    if tmpl
      template_name += '.xml'
      offset_row = tmpl[:row]
      offset_col = tmpl[:col]
    else
      offset_row = options[:offset_row]
      offset_col = options[:offset_col]
    end

    rows = options[:rows]
    count = options[:count] || (rows ? rows.size : 0)

    template = File.join(template_name)
    ret = ''

    OWC::Spreadsheet.open(template) do |book|
      sheet = book.Sheets(1)
      sheet.extend(OWC::Spreadsheet::Worksheet) # extend methods

      writer = Writer.new(sheet, headers, offset_row, offset_col, count)

      # setup data
      if block
        block.call(writer)
      else
        rows.each {|row| writer << row}
      end
      
      xml = book.XMLData
      #xml = book.mergedXMLData
      # output to
      ret = xml
    end # owc open
    ret
  end
  
  # OWC はセルの文字列折り返し設定を保持できないのでXML出力後にむりやり追加
  # options:
  #   :row     折り返し設定を追加する行
  def self.set_wrap_text(xml_doc, options={})
    REXML::XPath.each(xml_doc, "/ss:Workbook/ss:Worksheet") do |worksheet|
      row = options[:row] or raise "No row specified."
      style_ids = REXML::XPath.match(worksheet, "ss:Table/ss:Row[#{row}]/ss:Cell").group_by{|cell| cell.attributes["ss:StyleID"]}.keys
      style_ids.each do |style_id|
        alignment = REXML::XPath.first(xml_doc, "//ss:Style[@ss:ID='#{style_id}']/ss:Alignment")
        alignment.attributes["ss:WrapText"] = "1"
      end
    end
  end
  
end

