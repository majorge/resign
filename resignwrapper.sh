#! /bin/sh

if [ $# = 0 ]; then
	echo "Please provide a path where IPA files should be found"
	exit 1
fi
	
if [ -d $1 ]; then 
	find "$1" -type f -name "*.ipa" -exec ./unar {} -f \;
else
	echo "directory \"$1\" not found"
	exit 1
fi
