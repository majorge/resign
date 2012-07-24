require 'optparse'

options = {}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: resign-wrapper.rb [options]"

  opts.on("-d", "--directory [dir path]", "Directory containing IPAs to resign") do |d|
    options[:directory] = d
  end
  opts.on("-p", "--prov_profile_path [provisioning profile path", "Path to provisioning profile to resign with") do |p|
    options[:prov_profile_path] = p
  end
end.parse!

begin                                                                                                                                                                                                             
  mandatory = [:directory, :prov_profile_path]                     # Enforce the presence of                                                                                                                                                
  missing = mandatory.select{ |param| options[param].nil? }        # the -t and -f switches                                                                                                                        
  if not missing.empty?                                            #                                                                                                                                             
    puts "Missing options: #{missing.join(', ')}"                  #                                                                                                                                             
    puts optparse                                                  #                                                                                                                                             
    exit                                                           #                                                                                                                                             
  end                                                              #                                                                                                                                            
rescue OptionParser::InvalidOption, OptionParser::MissingArgument  #                                                                                                                                                
  puts $!.to_s                                                     # Friendly output when parsing fails
  puts optparse                                                    # 
  exit                                                             # 
end

dir = File.expand_path(options[:directory])
apps = Dir.foreach(dir) do |file|
  next if not file =~ /.*\.ipa/i

  system("./unar -force-overwrite \"#{dir}/#{file}\"")

  Dir.glob("Payload/*.app") do |i|
    system("./resign.rb --prov_profile_path #{options[:prov_profile_path]} --app_path \"#{File.expand_path(i)}\" --app_name \"#{file}\" --developerid \"iPhone Distribution: Mallinckrodt, Inc.\"")
  end
  
  Dir.glob("Payload/*.app") do |p|
    system("rm -rf \"#{File.expand_path(p)}\"")
  end
end