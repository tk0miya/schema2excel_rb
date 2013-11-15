#!/usr/bin/ruby

class ODBCSchema < Schema
  def dsn(password)
    options = {'Driver'        => 'SQL Server',
               'Server'        => @config['hostname'],
               'Port'          => @config['Port'] || 1433,
               'Database'      => @config['database'],
               'AutoTranslate' => 'No',
               'Trusted_Connection' => 'No',
               'Uid'           => @config['username'],
               'Pwd'           => password}
    params = options.collect{|k,v| sprintf("%s=%s", k, v)}.join(';')
    dsn = sprintf('dbi:%s:%s', @config['driver'], params)
  end

  def table_schema
    @config['owner']
  end

  def table_names
    unless @table_names
      rs = @cn.execute("select NAME from SYSOBJECTS where TYPE = 'U'")
      @table_names = rs.fetch_all.collect{|r| r[0]}.sort
      rs.finish

      @table_names.delete_if {|t| Schema.ignore_table?(t)}
    end

    @table_names
  end

  def set_table_descriptions
    self.table_names.each do |table_name|
      query = sprintf("SELECT ep.value as TABLE_COMMENT FROM sys.tables t " +
                      "LEFT JOIN sys.extended_properties ep ON ep.major_id = t.object_id " +
                      "WHERE ep.minor_id = 0 AND t.name = '%s'", table_name)
      rs = @cn.execute(query)
      if rs.fetchable? and rs.rows.nonzero?
         row = rs.fetch
         comment = row['TABLE_COMMENT']
         if comment && !comment.empty?
           Schema.set_description(table_name, comment)
         end
      end
      rs.finish
    end
  end

  def set_column_descriptions
    self.table_names.each do |table_name|
      query = sprintf("SELECT c.name, ep.value AS COLUMN_COMMENT FROM sys.tables t " +
                      "LEFT JOIN sys.columns c ON c.object_id = t.object_id " +
                      "LEFT JOIN sys.extended_properties ep ON ep.major_id = c.object_id AND ep.minor_id = c.column_id " +
                      "WHERE t.name = '%s'", table_name)
      rs = @cn.execute(query)
      rs.fetch_all.each do |row|
        if row[1]
          column_name = sprintf('%s.%s', table_name, row[0])
          Schema.set_description(column_name, row[1])
        end
      end
      rs.finish
    end
  end

  def set_column_constraint
    self.table_names.each do |table_name|
      query = sprintf("SELECT k.CONSTRAINT_NAME, k.TABLE_NAME, k.COLUMN_NAME, c.CONSTRAINT_TYPE, " +
                      "u.TABLE_NAME AS REFERENCED_TABLE_NAME, u.COLUMN_NAME AS REFERENCED_COLUMN_NAME FROM information_schema.table_constraints c " +
                      "LEFT JOIN information_schema.key_column_usage k ON " +
                      "c.TABLE_SCHEMA = k.TABLE_SCHEMA AND c.TABLE_NAME = k.TABLE_NAME AND c.CONSTRAINT_NAME = k.CONSTRAINT_NAME "  +
                      "LEFT JOIN information_schema.constraint_column_usage u ON k.TABLE_SCHEMA = u.CONSTRAINT_SCHEMA AND c.CONSTRAINT_NAME = u.CONSTRAINT_NAME " +
                      "WHERE c.TABLE_SCHEMA = '%s' AND k.TABLE_NAME = '%s'", self.table_schema, table_name)
      rs = @cn.execute(query)
      rs.fetch_all.each do |row|
        KeyHolder.update(row.to_h)
      end
      rs.finish
    end
  end
end
