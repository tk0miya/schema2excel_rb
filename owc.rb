require 'win32ole-ext'
require 'rexml/document'

module OWC
  def self.getAbsolutePath filename
    fso = WIN32OLE.new_with_const('Scripting.FileSystemObject', ::OWC)
    fso.GetAbsolutePathName(filename)
  end
end

module OWC
  module Spreadsheet
    def self.new
      return WIN32OLE.new_with_const('OWC11.Spreadsheet', ::OWC::Spreadsheet)
    end

    def self.open(filepath, &block)
      begin
        excel = self.new
        excel.extend(::OWC::Spreadsheet)
        excel.XMLURL = ::OWC.getAbsolutePath(filepath)
        excel.keep_neglected_tags(filepath)
        block.call(excel)
      ensure
        ;
      end
    end
    
    # OWC �̑���ɂ�莸���Ă��܂��y�[�W�ݒ�Ȃǂ�ޔ�
    def keep_neglected_tags(filepath)
      @neglected_tags = {}
      doc = nil
      File.open(filepath, 'rb') {|f| doc = f.read}
      xml_doc = REXML::Document.new(doc)
      if worksheet_options = REXML::XPath.match(xml_doc, "//x:WorksheetOptions | //WorksheetOptions[@xmlns='urn:schemas-microsoft-com:office:excel']")
        ["PageSetup", "FitToPage", "Print", "Zoom", "PageBreakZoom"].each do |name|
          @neglected_tags[name] = REXML::XPath.first(worksheet_options, "#{name} | x:#{name}")
        end
      end
    end
    
    # OWC �̑���ɂ�莸���Ă��܂��^�O��⊮����XML��Ԃ�
    # NOTE: �e���v���[�g�P�V�[�g�����̂܂܏o�́A�܂��͕����V�[�g�ɕ�������p�^�[���ȊO�ɂ͑Ή����Ă��܂���
    def mergedXMLData
      xml_doc = REXML::Document.new(self.XMLData)
      REXML::XPath.each(xml_doc, "//x:WorksheetOptions | //WorksheetOptions[@xmlns='urn:schemas-microsoft-com:office:excel']") do |worksheet_options|
        @neglected_tags.each do |name, tag|
          if tag && !REXML::XPath.first(worksheet_options, "#{name} | x:#{name}")
            # NOTE: REXML �̃o�[�W�����ɂ���Ă� namespace ss ���F���ł��Ȃ��� REXML::UndefinedNamespaceException �𓊂���̂�
            # NOTE: �_�~�[�� root �� namespace ���w��
            clone = REXML::Document.new("<root xmlns:x=''>#{tag}</root>").root.children.first
            # namespace x: ������
            REXML::XPath.each(clone, "//*") {|e| e.name = "x:#{e.name}"}
            # �ǉ�
            worksheet_options << clone
          end
        end
      end
      xml_doc.to_s
    end
    
    def save(filepath)
      begin
        self.Export(filepath, 0, 1) # 0: auto select(maybe 1), 1: xml, 2: HTML
      ensure
        ;
      end
    end
  end
end

module OWC
  module Spreadsheet
    module Worksheet
      def next_col(y, x)
        cell = self.Cells.Item(y, x)
        if cell.MergeCells
          x + cell.MergeArea.count
        else
          x + 1
        end
      end 

      def [] y,x
        cell = self.Cells.Item(y,x)
        if cell.MergeCells
          cell.MergeArea.Item(1,1).Value
        else
          cell.Value
        end
      end

      def []= y,x,value
        cell = self.Cells.Item(y,x)
        if cell.MergeCells
          cell.MergeArea.Item(1,1).Value = value
        else
          cell.Value = value
        end
      end
    end
  end
end


