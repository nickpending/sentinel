#!/usr/bin/ruby
require "ensure/encoding"
require "digest"
require "pp"
require 'net/http'
require 'openssl'
require 'json'
require 'fileutils'
require 'highline/import'
require './Code_Filter'
require './Positive_Result'

#capture any options
parse = false
update = false
domain = ""
user = ""
ARGV.each do|a|
  update = true if a == "update"
  parse = true if a == "parse"
  domain = a[2..-1] if a[0..1] == "-d"
  user = a[2..-1] if a[0..1] == "-u"
end
if !update && !parse
	puts "Usage: [ [update] [-d[domain]] [-u[username]] ] [parse]"
	puts "For example:"
	puts "$ruby sentinel.rb update -dbitbucket.com -uFred"
	puts "or just to grep what you already have:"
	puts "$ruby sentinel.rb parse"
end

def getProjectResults(results, value)
	results.store(value['key'],value['id']) if !(value['key'] =~ /SAN/)
end

def getRepositoryResults(results, value)
        projFolder = value['project']['key']
        repoFolder = value['slug']
        gitLink = ""
        value['links']['clone'].each do |v|
        	if (v['name'] =~ /http/)
        		gitLink = v['href']
        	end
        end
        results.store("./#{projFolder}/#{repoFolder}", gitLink)
end

:project
:repository
def getAllPaginatedResults(domain, endpoint, user, pass, type)
	isLastPage=false
	start=0
	results=Hash.new
	while !isLastPage
		uri=URI("https://#{domain}#{endpoint}?start=#{start}")
		puts "Querying...  #{uri}"
		Net::HTTP.start(uri.host, uri.port,
		 :use_ssl => uri.scheme == 'https',
		 :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
			request = Net::HTTP::Get.new uri.request_uri
			request.basic_auth user, pass
			response = http.request request #Net::HTTPResponse object
			objResp = JSON.parse(response.body)
			objResp['values'].each do |e|
				if (type == :project)
					getProjectResults(results,e)
				else
					getRepositoryResults(results,e)
				end
			end
			start = objResp['nextPageStart']
			isLastPage = objResp['isLastPage']
		end
	end
	return results
end

if update
	#Set up the bitbucket repository
	puts "Connectiong to domain... #{domain}"
	puts "User: #{user}"
	pass = ask("Password: ") {|q| q.echo = false}
	
	#Load the projects
	projEndpoint = "/rest/api/1.0/projects"
	projects = Hash.new
	projects = getAllPaginatedResults(domain,projEndpoint,user,pass,:project)
	
	#load the repositories
	repos = Hash.new
	projects.each do |k,v|
		repoEndpoint = "/rest/api/1.0/projects/"
		repoEndpoint += "#{k}/repos"
		repos.merge!( getAllPaginatedResults(domain,repoEndpoint,user,pass,:repository) )
	end
	
	#Delete local repos if they don't exist upstream anymore
	localRepos = Array.new
	Dir["../*"].each do |d|
		if File.directory?(d)
			Dir["#{d}/*"].each do |e|
				localRepos.push(e) if File.directory?(e) && e[-8..0]=="sentinel"
			end
		end
	end
	localRepos.each do |r|
		puts "Deleting... #{r}" if !(repos.key?(r))
		FileUtils.rm_rf(r) if !(repos.key?(r))
	end
	
	#Create directories for all projects
	projects.each do |f,v|
		FileUtils.mkdir_p("../#{f}")
	end
	
	#Download or update all repos
	Dir.chdir("..")
	rootFolder = Dir.pwd
	repos.each do |f,g|
		if Dir.exists?(f) #just update the existing repo
			Dir.chdir(f)
			puts "Updating... #{f}"
			system "git fetch"
			system "git pull"
			Dir.chdir(rootFolder)
		else #git clone
			system "git clone #{g} #{f}"
		end
	end
end

if parse
	keywordsRex = /crypt|[^a-z,A-Z]rand|doFinal|cipher|aes|hmac/i
	#Collect our list of matching filenames
	m = Array.new
	Dir.glob("../**/*").each do |f|
		if File.file?(f)
			open(f) {|c| #this is the code that needs to be efficient
				matchCount = c.read
					.ensure_encoding('UTF-8',:invalid_characters => :drop)
					.lines
					.grep(keywordsRex)
					.size
				firstMatch = 0
				if (matchCount > 0)
					m.push( Positive_Result.new(f, 0, matchCount, "") )
				end
			}
		end
	end
	
	#Get the line number of the first match
	m.each do |x|
		linenum = 0
		lines = File.file?(x.uri) ? File.read(x.uri)
			.ensure_encoding('UTF-8',:invalid_characters => :drop)
			.lines : Array.new
		lines.each do |l|
			linenum += 1
			if x.firstMatch == 0 && l =~ keywordsRex
				x.firstMatch = linenum
			end
		end
	end
	
	#Load the exclusions
	exclusions = Hash.new
	f = "sentinelExclusions.txt"
	lines = File.file?(f) ? File.readlines(f) : Array.new
	lines.each do |l|
		t = l.chomp.split('|')
		exclusions[t[2]] = t[3]
		# exclusions look like { "uri" => "hash" } in memory
		# exclusions look like:
		# "line of first match|total match count|uri|hash" in a file
	end
	
	#Print the files which aren't already excluded
	output = "{\"Results\":["
	m.each do |i|
		i.hash = Digest::SHA256.hexdigest(File.read(i.uri))
		if exclusions[i.uri]!=hash && Code_Filter.isValid(i.uri)
			output += i.to_json
			output += ","
		end
	end
	output = output[0...-1]
	output += "]}"
	#puts output
	pp JSON.parse(output)
end
