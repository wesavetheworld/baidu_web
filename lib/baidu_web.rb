# encoding: utf-8
$:.unshift(File.dirname(__FILE__))

require 'hpricot'
require 'open-uri'
#require 'iconv'
#require 'cgi'
require "baidu_web/version"
require "baidu_web/record"
require "baidu_web/extension_key"
require "baidu_web/string_extension"
require "baidu_web/strip"

module BaiduWeb
  class << self
	  def search(key_word, options)
	  	result = {:record_arr => [], :ext_key_arr => [], :source => 'web'}

	  	#@ic = Iconv.new("UTF-8//IGNORE", "GBK//IGNORE")

	  	@key_word = key_word
	  	return result if @key_word.blank?
	  	#uri parser key word
	  	# @key_word = CGI.escape(@key_word)

	  	#determine how many records display on one page. (same as www.baidu.com/?<some params>&rn=50)
	  	@per_page = options[:per_page]
	  	@per_page ||= 50

	  	#get which page of result. (same as www.baidu.com/?<some params>&pn=0)
	  	@page_index = options[:page_index]
	  	@page_index ||= 1

	  	#get the start item index.
	  	item_index = (@page_index - 1 ) * @per_page

	  	agent = Mechanize.new

  		url = "http://www.baidu.com/s?wd=#{@key_word}&rn=#{@per_page}&pn=#{item_index}"
  		#debug: url
  		spage = agent.get(url)
  		#debug
  		# File.open(File.join(File.dirname(__FILE__), 'baidu_result.html'), "w"){|f| f.write(@ic.iconv(spage.body))}

  		#doc = Hpricot(@ic.iconv(spage.body))
  		doc = Hpricot(spage.body)

	  	#- this is hack on linux:
	  	#case1:
	  	# result_page = @ic.iconv(open("http://www.baidu.com/s?wd=#{@key_word}&rn=#{@per_page}&pn=#{item_index}").read)
	  	#case2:
	  	# result_page = ""
	  	# open("http://www.baidu.com/s?wd=#{@key_word}&rn=#{@per_page}&pn=#{item_index}", "r:utf-8") {|f|
  		#   f.each_line do |line|
  		#   	 result_page += @ic.iconv(line)
  		#   end
	  	# }

  		return result if doc.blank?
  
  		result[:record_arr] = extract_item(doc, item_index)
  		result[:ext_key_arr] = extract_extension_key(doc)
  		#debug
  		puts result[:record_arr].size
  
  		return result
	  end
  
	  private
	  def extract_item(content, item_index)
	  	record_arr = []
	  	#remove op recors, e.g. search by 'mysql', see the second record.
	  	content.search("table[@class='result-op']").remove

			content.search("table[@class='result']").each do |res|
				next if res.at("h3").nil?

				record = Record.new

				title = res.at("h3").inner_text
				record.title = title
				record.url = res.at("h3").at("a").attributes['href'].to_s

				summary = []
				res.at("td[@class='f']").children.each do |elem|
			  	if elem.respond_to?(:attributes) && elem.attributes['href'] =~ /http:\/\/cache.baidu.com/
			  	  record.cached_url = elem.attributes['href'] 
			  	  next
			  	elsif elem.respond_to?(:attributes) && elem.attributes['class'] == 'g' && elem.to_s =~ /(\d{4}-\d{1,2}-\d{1,2})/
			  	  record.updated_date = $1
			  	  next
			    end
			    next if elem.respond_to?(:attributes) && elem.attributes['class'] == 't'
			    summary << elem.inner_text
				end
				record.summary = summary.join(' ').gsub(/百度|百度快照|快照/, '')

				item_index += 1
				record.item_index = item_index
				record_arr << record
			end
			return record_arr
	  end

	  def extract_extension_key(doc)
	  	rs = doc.at("//div#rs")
	  	return [] if rs.nil?
	  	ext_key_arr = []
	  	rs.get_elements_by_tag_name("a").each do |link|
	  	   ext_key = ExtensionKey.new
	  	   ext_key.title = link.inner_text
	  	   ext_key.parent_key = @key_word
	  	   ext_key.source = 'web'
	  	   ext_key_arr << ext_key
	  	end
	  	ext_key_arr
	  end

	end
end
