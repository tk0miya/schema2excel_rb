#!/usr/bin/ruby

class PgSchema < Schema
  def table_schema
    @config['schema']
  end

  def table_names
    unless @table_names
      query = sprintf("SELECT table_name FROM information_schema.Tables " +
                      "WHERE TABLE_SCHEMA = '%s'", self.table_schema)
      rs = @cn.execute(query)
      @table_names = rs.fetch_all.collect{|r| r[0]}.sort
      rs.finish

      @table_names.delete_if {|t| Schema.ignore_table?(t)}
    end

    @table_names
  end

  def set_table_descriptions
    self.table_names.each do |table_name|
      query = sprintf("SELECT obj_description(c.oid, 'pg_class') as TABLE_COMMENT FROM pg_class c " +
                      "LEFT JOIN pg_namespace n ON n.oid = c.relnamespace " +
                      "WHERE c.relkind = 'r' AND nspname = '%s' AND c.relname = '%s'",
                      self.table_schema, table_name)
      rs = @cn.execute(query)
      if rs.fetchable? and rs.rows.nonzero?
         row = rs.fetch
         comment = row['table_comment']
         if comment && !comment.empty?
           Schema.set_description(table_name, comment)
         end
      end
      rs.finish
    end
  end

  def set_column_descriptions
    self.table_names.each do |table_name|
      query = sprintf("SELECT a.attname, col_description(a.attrelid, a.attnum) AS COLUMN_COMMENT FROM pg_attribute a " +
                      "LEFT JOIN pg_class c ON c.oid = a.attrelid " +
                      "LEFT JOIN pg_namespace n ON n.oid = c.relnamespace " +
                      "WHERE c.relkind = 'r' AND nspname = '%s' AND relname = '%s' AND " +
                      "a.attnum > 0 AND NOT a.attisdropped", self.table_schema, table_name)
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
