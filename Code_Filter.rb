class Code_Filter
	
	def self.isFramework (filePath)
		fileName = File.basename(filePath)
		return true if fileName =~ /.*\.min\.js$|.*\.min\.map$/
		return true if fileName == "swagger-ui.js"
		return true if fileName == "swagger-oauth.js"
		return true if fileName == "marked.js"
		return true if fileName == "gradle.properties"
		return false
	end
	
	def self.isTestCode (filePath)
		fileName = File.basename(filePath)
		return true if fileName =~ /\.tst$|\.rsp$/
		return true if filePath =~ /\/src\/test/
		return false
	end
	
	def self.isCode (filePath)
		fileName = File.basename(filePath)
		return false if fileName =~ /\.ttf$|\.html$|\.htm$|\.css$|\.md$|
			\.markdown$/x
		return false if fileName =~ /ChangeLog|README/
		return false if filePath =~ /Documentation\/html\/|
			\/Docs-Generated\/html|authn-access\/html/x
		return false if fileName == "LICENSE"
		return false if fileName == "sentinel.rb"
		return false if fileName == "sentinel.rb~"
		return true
	end
	
	def self.isValid(filePath)
		return true if !isFramework(filePath) && !isTestCode(filePath) && isCode(filePath)
		return false
	end
end