#!/usr/bin/env ruby

require 'base64'
require 'openssl'
require 'base64'
require 'cgi'
require 'stringio'
require 'ftools'
require 'getoptlong'
require 'pathname'
require File.dirname(__FILE__)+"/generator.rb"
require File.dirname(__FILE__)+"/parser.rb"

#dev_id is the name of the identity passed in
dev_id=nil
#prov_profile_path is the posix path to the  provisioning profile
prov_profile_path=nil
#app_path is the posix path to the application bundle to sign
app_path=nil

app_name = nil

opts = GetoptLong.new(
    [ '--app_path', '-a', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--app_name', '-n', GetoptLong::REQUIRED_ARGUMENT ]
  )
  
opts.each do |opt, arg|
  case opt
     when '--app_path'
      app_path = arg
    when '--app_name'
      app_name = arg
  end
end  

info_plist_path="#{app_path}/Info.plist"
#$stderr.puts "   Converting Info.plist from binary to text..."
system("plutil -convert xml1 \"#{info_plist_path}\"")

#Read in the plist file, put into an array. We then save it out with help from the plist library.
file_data=File.read(info_plist_path)
info_plist=Plist::parse_xml(file_data)

custom_file_data = File.read('/Users/mikejorgensen/Desktop/test.plist')
custom_plist = Plist::parse_xml(custom_file_data)

# *** Merge custom plist info info.plist ***
custom_plist.each{|entry|
	info_plist[entry[0]] = entry[1]
}

# *** Print resultant info.plist ***
info_plist.each{|entry|
	puts "Key: #{entry[0]}"
	puts "Value: #{entry[1]}"
}