#!/bin/bash

##################################################
# Usage and args processing
##################################################

usage() { echo "Usage: $0 [-d <date (ie. "YYYY-MM-DD")> || [-f <filename>]" 1>&2; exit 1; }

while getopts ":d:f:" o; do
    case "${o}" in
        d)
            file_date=${OPTARG}
            ;;
        f)
            file_name=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${file_date}" ] && [ -z "${file_name}" ]; then
    usage
fi

##################################################
# Main
##################################################

#echo "file_date = ${file_date}"
#echo "file_name = ${file_name}"

# Add all matching files to file list array regardless of file_name or file_date glob
if [ ! -z "${file_date}" ]; then
  myFilesArray=(./${file_date}*)
  commit="${file_date} glob"
else
  myFilesArray=(./${file_name})
  commit="${file_name}"
fi
  
# Move files to ~/temp, remove them from the git stage, commit, push
for fileName in ${myFilesArray[@]}; do
  mv ${fileName} ~/temp/
  git rm ${fileName}
done
git commit -m "Removed ${commit}"
git push

# Move files from ~/temp, add them to the git stage, commit, push
for fileName in ${myFilesArray[@]}; do
#  echo $fileName
  mv ~/temp/${fileName} .
  git add ${fileName}
done
git commit -m "Re-added ${commit}"
git push
