#! /bin/sh

if [ $# = 0 ]; then
	echo "Please provide a path where IPA files should be found"
	exit 1
fi

if [ -f $2 ]; then
	#nop
	prov_profile=$2
else
	echo "Please provide a path to the provisioning file"
	exit 1
fi
	
if [ -d $1 ]; then 
	find "$1" -type f -name "*.ipa" -exec sh -c "./unar -f '{}' && ./resign.rb --prov_profile_path $prov_profile --developerid 'iPhone Distribution: Mallinckrodt, Inc.' --app_path Payload/Signup.app" \;
else
	echo "directory \"$1\" not found"
	exit 1
fi
