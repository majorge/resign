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
    [ '--prov_profile_path', '-p', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--app_path', '-a', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--developerid', '-d', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--app_name', '-n', GetoptLong::REQUIRED_ARGUMENT ]
  )
  
opts.each do |opt, arg|
  case opt
    when '--prov_profile_path'
      prov_profile_path=arg
     when '--app_path'
      app_path = arg
    when '--developerid'
      dev_id = arg
    when '--app_name'
      app_name = arg
  end
end
  
throw "file #{prov_profile_path} does not exist" if !File.exists?(prov_profile_path)
  

info_plist_path="#{app_path}/Info.plist"
$stderr.puts "   Converting Info.plist from binary to text..."
system("plutil -convert xml1 \"#{info_plist_path}\"")

#Read in the plist file, put into an array. We then save it out with help from the plist library.
file_data=File.read(info_plist_path)
info_plist=Plist::parse_xml(file_data)

#update version number
#info_plist['CFBundleVersion'] += '.1'
#$stderr.puts "   Updating Info.plist with new bundle version of #{info_plist['CFBundleVersion']}..."

#update bundle ID
bundleid = info_plist['CFBundleIdentifier']
#$stderr.puts "   Current Bundle Identifier #{bundleid}..."

matches = /^com\.mallinckrodt\..*$/.match(bundleid)
#$stderr.puts "#{matches}"

#bundleid.split(".").each{|s| puts s}

$stderr.puts "com.mallinckrodt." + bundleid.split(".").last