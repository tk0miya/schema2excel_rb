#!/usr/bin/ruby

class MySQLSchema < Schema
  def connect(password)
    @cn = super(password)
    @cn.do('SET NAMES sjis')

    @cn
  end

  def table_schema
    @config['database']
  end

  def set_table_descriptions
    self.table_names.each do |table_name|
      query = sprintf("SELECT * FROM information_schema.Tables " +
                      "WHERE TABLE_SCHEMA = '%s' AND TABLE_NAME = '%s'", self.table_schema, table_name)
      rs = @cn.execute(query)
      if rs.fetchable?
         row = rs.fetch
         comment = row['TABLE_COMMENT'].sub(/(; )?InnoDB free.*$/, '')
         if !comment.empty? && row['TABLE_TYPE'] != 'VIEW'
           Schema.set_description(table_name, comment)
         end
      end
      rs.finish
    end
  end

  def set_column_descriptions
  end

  def set_column_constraint
    self.table_names.each do |table_name|
      query = sprintf("SELECT CONSTRAINT_NAME, TABLE_NAME, COLUMN_NAME, CONSTRAINT_TYPE, " +
                      "REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME FROM information_schema.table_constraints c " +
                      "LEFT JOIN information_schema.key_column_usage k USING (TABLE_SCHEMA, TABLE_NAME, CONSTRAINT_NAME) " +
                      "WHERE TABLE_SCHEMA = '%s' AND TABLE_NAME = '%s'", self.table_schema, table_name)
      rs = @cn.execute(query)
      rs.fetch_all.each do |row|
        KeyHolder.update(row.to_h)
      end
      rs.finish
    end
  end
end
