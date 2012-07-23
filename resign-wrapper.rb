require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: resign-wrapper.rb [options]"

  opts.on("-d", "--directory [dir path]", "Directory containing IPAs to resign") do |d|
    options[:directory] = d
#    puts d
  end

  opts.on("-p", "--prov_profile_path [provisioning profile path", "Path to provisioning profile to resign with") do |d|
    options[:prov_profile_path] = d
  end
  
end.parse!

#  puts options[:directory]
dir = File.expand_path(options[:directory])
apps = Dir.foreach(dir) do |file|
  next if not file =~ /.*\.ipa/i

#  IO.popen("./unar \"#{options[:directory]}#{file}\"") { |io| while (line = io.gets) do puts line end }
#  puts file
  system("./unar -force-overwrite \"#{dir}/#{file}\"")

  puts Dir.glob("Payload/*.app") {|i| system("./resign.rb --prov_profile_path #{options[:prov_profile_path]} --app_path \"#{File.expand_path(i)}\" --developerid \"iPhone Distribution: Mallinckrodt, Inc.\"") }
  
  

  Dir.glob("Payload/*.app") do |p|
#    File.chmod(777, p)
    system("rm -rf \"#{File.expand_path(p)}\"")
  end
end