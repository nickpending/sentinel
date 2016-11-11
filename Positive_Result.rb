class Positive_Result
	attr_accessor :uri
	attr_accessor :firstMatch
	attr_accessor :matchCount
	attr_accessor :hash
	def initialize(uri, firstMatch, matchCount, hash)
		@uri = uri
		@firstMatch = firstMatch
		@matchCount = matchCount
		@hash = hash
	end
	def to_json(*a)
		{"firstMatch" => @firstMatch, "matchCount" => @matchCount, "uri" => @uri, "hash" => @hash}.to_json(*a)
	end
end