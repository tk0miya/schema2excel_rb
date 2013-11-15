require 'win32ole'

class WIN32OLE
  @const_defined = Hash.new
  def WIN32OLE.new_with_const(prog_id, const_name_space)
    result = WIN32OLE.new(prog_id)
    unless @const_defined[const_name_space] then
      WIN32OLE.const_load(result, const_name_space)
      @const_defined[const_name_space] = true
    end
    return result
  end
end

