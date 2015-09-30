#!/usr/bin/env ruby

require 'base64'
require 'openssl'
require 'base64'
require 'cgi'
require 'stringio'
require 'fileutils'
require 'getoptlong'
require 'pathname'
require File.dirname(__FILE__)+"/generator.rb"
require File.dirname(__FILE__)+"/parser.rb"

def self.sign_to_der(certPEM, privateKeyPEM, dataToSign)
  cert = OpenSSL::X509::Certificate.new(certPEM)
  privateKey = OpenSSL::PKey::RSA.new(privateKeyPEM)
  
  flags = OpenSSL::PKCS7::BINARY
  pkcs7 = OpenSSL::PKCS7::sign(cert, privateKey, dataToSign, nil, flags)
  
  return pkcs7.to_der
end

# Remove the data from the signed package. Don't worry about
# checking the signature.
def self.unwrap_signed_data(signedData)
  pkcs7 = OpenSSL::PKCS7.new(signedData)
  store = OpenSSL::X509::Store.new
  flags = OpenSSL::PKCS7::NOVERIFY
  pkcs7.verify([], store, nil, flags) # Verify it so we can pull out the data
  return pkcs7.data
end

def subject_from_cert(inCert)
    certificate=OpenSSL::X509::Certificate.new inCert
    subject=certificate.subject.to_s

    subject=subject[/CN=.*?\//].sub!("CN=","").sub("\/","")
    return subject
end

# go through an array of strings and see if they match identities in the keychain.  Note that the 
# identities much start with iPhone and be of type codesigning.
def find_matching_identities (inCertificateSubjects)
    #get identities using the commmand line tool security
    identities=`security find-identity -v -p codesigning`
    #create an array
    identities=identities.split("\n")

    #identity_labels is the common name of all the matching certs.
    identity_labels=[]
    
    #loop over the certs that came in and compare to each identity from the keychain
    inCertificateSubjects.each{|certSubject| 
        identities.each { |id| 
            #only use identities that start with iPhone.  This could cause issues later.
            if id[/iPhone.*/] then
                #we have a trailing quote, so need to delete it
                label=id[/iPhone.*/].delete!("\"")
                #if we match, then we found an identity that should be saved and
                #we add it to our array
                if (label==certSubject) then
                    identity_labels.push certSubject
#                    $stderr.puts "Matched #{label}"
                end
            end
        }
    }
    return identity_labels
end

#dev_id is the name of the identity passed in
dev_id=nil
#prov_profile_path is the posix path to the  provisioning profile
prov_profile_path=nil
#app_path is the posix path to the application bundle to sign
app_path=nil

app_name = nil

#setup the arguments
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

$stderr.puts "******** Starting resign of #{app_name} ********"

throw "file #{prov_profile_path} does not exist" if !File.exists?(prov_profile_path)

#read in the signed provisioning profile from disk and extract plist.
#we don't care who signed it.

#$stderr.puts "   Reading in provisioning profile..."
signedData=File.read(prov_profile_path)
r = Plist::parse_xml(unwrap_signed_data(signedData))
puts r

#get the entitlements from the profile
app_id = r['Entitlements']['application-identifier']
#strip off vendor ID
app_id = app_id.split(".")[1,app_id.length].join "."
entitlements = r['Entitlements']

#build an array of subjects from each developer certificate
#certificateSubjects is an array that we'll store the names
certificateSubjects=[]

#get all the dev certificates.  We get back a ref to a StringIO
#not a string, so we have to read them in.
certificatesArray=r['DeveloperCertificates']

#we iterate over all the certicates and save them in an array
#and also detect if a match is found.  We do both because
#this tool can be called with or without a dev_id.  If it is
#called without a dev_id, then all of the matching certificates are
#returned.  If a dev_id is provided, we mark it as found and they use that.
#waste a bit of memory but this shortens how much code is used.

found=false
certificatesArray.each { |inCert| 
    curSubject=subject_from_cert(inCert.read)
    certificateSubjects.push curSubject
    if ((dev_id!=nil) and (dev_id==curSubject) ) then
        found=true
    end
}

#$stderr.puts "found "+certificatesArray.count.to_s+" certificates"

#if we don't have a dev_id, then we just return the matched certificates and
#exit
if (dev_id==nil) 
    matchingArray=find_matching_identities(certificateSubjects)
    #puts matchingArray.uniq.join("\n") 
    exit
end

#check to make sure the app passed in really exists
throw "file #{app_path} does not exist" if !File.exists? app_path


#verify existing signature
#sig_results = system("/usr/bin/codesign -f -s \"#{dev_id}\" \"#{app_path}\" --verify --deep -vvv -s \"iPhone Distribution: Mallinckrodt, Inc.\" ")
#$stderr.puts sig_results

######## INFO.PLIST ########
#the plist is most likely in binary format, so we change to text
#otherwise the plist library fails
info_plist_path = "#{app_path}/Info.plist"
#$stderr.puts "   Converting Info.plist from binary to text..."
system("plutil -convert xml1 \"#{info_plist_path}\"")

#Read in the plist file, put into an array. We then save it out with help from the plist library.
file_data=File.read(info_plist_path)
info_plist=Plist::parse_xml(file_data)

#update version number
def new_version_number(version_number)
  if version_number.nil? then return version_number end
	
  version_parts = version_number.split(".")
  if version_parts.length == 2 then
  	# add a bugfix number portion to the version_number
  	version_parts[2]= 0
  end
  version_parts[version_parts.length-1] = (version_parts.last.to_i + 1).to_s
  version_parts.join(".")
end

# todo: create a class that contains the following attributes:
#         CFBundleIdentifier
#         CFBundleShortVersionString
#         CFBundleVersion
#         CFBundleDisplayName
#         CFBundleName


#change bundle id to match provisioning profile
#TODO: actually lookup the provisioning profile bundle id
original_CFBundleIdentifier = info_plist['CFBundleIdentifier']
new_CFBundleIdentifier = "com.mallinckrodt." + original_CFBundleIdentifier.split(".").last
if original_CFBundleIdentifier != new_CFBundleIdentifier then
  $stderr.puts "  Updating CFBundleIdentifier from #{original_CFBundleIdentifier} to #{new_CFBundleIdentifier}..."
  info_plist['CFBundleIdentifier'] = new_CFBundleIdentifier
  $stderr.puts "    Version numbers unchanged at #{info_plist['CFBundleShortVersionString'] if info_plist.has_key?('CFBundleShortVersionString')} and #{info_plist['CFBundleVersion']}"
else
  # bump version number if we're resigning our own provisioned IPA
  if info_plist.has_key?('CFBundleVersion') then
    $stderr.puts " Original CFBundleVersion: #{info_plist['CFBundleVersion']}"
    if info_plist.has_key?('CFBundleShortVersionString') then
	  $stderr.puts " Original CFBundleShortVersionString: #{info_plist['CFBundleShortVersionString']}"
	  info_plist['CFBundleShortVersionString'] = new_version_number(info_plist['CFBundleShortVersionString'])
    end

    info_plist['CFBundleVersion'] = new_version_number(info_plist['CFBundleVersion'])

    $stderr.puts "   Updated Info.plist with new CFBundleShortVersionString of #{info_plist['CFBundleShortVersionString']} and CFBundleVersion of #{info_plist['CFBundleVersion']}..."
  end
end

info_plist['CFBundleDisplayName'] = info_plist['CFBundleName'] if info_plist['CFBundleDisplayName'] == ""

#$stderr.puts "   Saving updated Info.plist to app bundle..."
info_plist.save_plist info_plist_path


######## ENTITLEMENTS ########

#Copy current
entitlements_path = "#{app_path}/Entitlements.plist"
if File.exists?(entitlements_path) then
	entitlements_file_data=File.read(entitlements_path)
	entitlements_plist=Plist::parse_xml(entitlements_file_data)
	$stderr.puts("Original application-identifier: #{entitlements_plist["application-identifier"]}")
else
	$stderr.puts("No original Entitlements.plist")
end


#App store: 48R29Y2GN7
#Enterprise: 5MAHELGYCK
  entitlements["application-identifier"] = "5MAHELGYCK.#{new_CFBundleIdentifier}"
#  entitlements["application-identifier"] = "5MAHELGYCK.com.mallinckrodt.*"
#  entitlements["application-identifier"] = entitlements_plist["application-identifier"]
#  puts "*******NEW application-identifier*******"
#  puts entitlements["application-identifier"]
  
  #if !entitlements.has_key?('previous-application-identifiers') then
  	#entitlements['previous-application-identifiers'] =  ['5MAHELGYCK.com.mallinckrodt.*']
  	#<key>previous-application-identifiers</key>
    #<array>
    #    <string>{Your Old App ID Prefix}.YourApp.Bundle.ID</string>
    #</array>
  #end

#$stderr.puts "   Saving updated Entitlements to app bundle..."
entitlements.save_plist("#{app_path}/Entitlements.plist")

#Dump the old embedded.mobileprovision and copy in the one provided
#$stderr.puts "   Removing the prior embedded.mobileprovision..."
File.unlink("#{app_path}/embedded.mobileprovision") if File.exists? "#{app_path}/embedded.mobileprovision"

#$stderr.puts "   Moving provisioning profile into app..."
FileUtils.copy(prov_profile_path,"#{app_path}/embedded.mobileprovision")

#now we sign the whole she-bang using the info provided
#$stderr.puts "running /usr/bin/codesign -f -s \"#{dev_id}\" \"#{app_path}\" --entitlements=\"#{app_path}/Entitlements.plist\""
result=system("/usr/bin/codesign -f -s \"#{dev_id}\" \"#{app_path}\" --entitlements=\"#{app_path}/Entitlements.plist\"")

#$stderr.puts "codesigning returned #{result}"
throw "Codesigning failed" if result==false

app_folder=Pathname.new(app_path).dirname.to_s
newFolder="#{app_folder}/#{app_name.gsub(".ipa", "")}"
#$stderr.puts newFolder

#we add the .app into a Payload folder and then zip it 
#up with the extension .ipa so it can easiy be added to iTunes
#However, we must account for the fact that a duplicate folder name
#exists.  We just add an integer onto the end if we find it.

i=1
while (File.exists? newFolder)
    newFolder="#{app_folder}/#{app_name.gsub(".ipa", "")}"+"-"+i.to_s
    i+=1
end

#create the new folder and a payload folder
Dir.mkdir(newFolder)
Dir.mkdir("#{newFolder}/Payload")
FileUtils.move(app_path,"#{newFolder}/Payload")

#zip it up.  zip is a bit strange in that you have to actually be in the 
#folder otherwise it puts the entire tree (though empty) in the zip.
system("pushd \"#{newFolder}\" && 
/usr/bin/zip -r \"#{info_plist['CFBundleDisplayName']}-#{info_plist['CFBundleShortVersionString']} (#{info_plist['CFBundleIdentifier']})\.ipa\" Payload > /dev/null")

#extract icons
iPad = info_plist.has_key?('CFBundleIcons~ipad')
no_platform = info_plist.has_key?('CFBundleIconFiles')
if no_platform then
	iPad_string = ""
elsif iPad then 
	iPad_string = '~ipad' 
end

#info_plist["CFBundleIcons#{iPad_string}"]['CFBundlePrimaryIcon']['CFBundleIconFiles'].each{|file|
#	full_path= "#{newFolder}/Payload/#{Pathname.new(app_path).basename}/#{file}#{iPad_string}.png" #this .png might not be necessary in all cases...what to do?
#	shorter_path= "#{newFolder}/Payload/#{Pathname.new(app_path).basename}/#{file}.png" #ditto, might not need to add.png

#	if File.exists?(full_path) then
#		File.cp("#{full_path}", "#{newFolder}")
#	elsif File.exists?(shorter_path) then
#		File.cp("#{shorter_path}", "#{newFolder}")
#	else
#		#puts "File #{file} could not be found using #{full_path} or #{shorter_path}"
#		#File.cp("#{file}*", "#{newFolder}")
#		Dir.glob("#{newFolder}/Payload/#{Pathname.new(app_path).basename}/*#{file}*").each{ |file|
#			File.cp(file, "#{newFolder}")
#		}
#	end
#}

system("pushd \"#{newFolder}\" > /dev/null && rm -rf Payload")