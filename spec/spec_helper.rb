require 'fileutils'

#require 'scalebar'
class Output
  def messages
    @messages ||= []
  end
  
  def puts(message)
    messages << message
  end
end

def myout
  @output ||= Output.new
end

def deleteall(delthem)
	if FileTest.directory?(delthem) then
		Dir.foreach( delthem ) do |file|
			next if /^\.+$/ =~ file
			deleteall(delthem.sub(/\/+$/,"") + "/" + file)
		end
		#p "#{delthem} deleting..."		
		Dir.rmdir(delthem) rescue ""
	else
		#p "#{delthem} deleting..."
		File.delete(delthem)
	end
end

def setup_empty_dir(dirname)
	deleteall(dirname) if File.directory?(dirname)
	FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
end

def setup_file(destfile)
	src_dir = File.expand_path('../fixtures/files',__FILE__)
	filename = File.basename(destfile)
	dest_dir = File.dirname(destfile)
	dest = File.join(dest_dir, filename)
	src = File.join(src_dir, filename)
	FileUtils.mkdir_p(dest_dir) unless File.directory?(dest_dir)
	FileUtils.copy(src, dest)
end
