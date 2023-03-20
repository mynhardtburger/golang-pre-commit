#!/bin/bash

# This will try to verify the copyrights for the given file extension.

FILE_EXT=$1
shift

FILES=

while [[ $# -gt 0 ]]; do
  FILES="$1 ${FILES}"
  shift
  continue
done

if [[ "${FILE_EXT}" == "" ]]; then
  echo "No file extension found"
  exit 1
fi

# git status -s --porcelain | awk '{ $1=""; print substr($0,2) }'
# $(git ls-tree -r --name-only HEAD)
if [[ "${FILES}" == "" ]]; then
  FILES=$(git status -s --porcelain | awk '{ $1=""; print substr($0,2) }')
fi

echo "Checking files ${FILES}"

set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# git fetch --unshallow &> /dev/null

commitYear=$(date +'%Y')

declare -a fileextensions=("${FILE_EXT}") # ("go")

#declare -a ignore=()
#if [ -f .copyrightignore ]; then
#  IFS=$'\n' read -d '' -r -a ignore < .copyrightignore
#fi

# echo "Ignored files: "
# for e in "${ignore[@]}"; do echo "    - $e"; done

function shouldCheck() {
  local filename=$(basename "$1")
  local fileExtension="${filename##*.}"
  # for e in "${ignore[@]}"; do [[ "$1" =~ $e && "$e" != "" ]] && return 1; done
  for e in "${fileextensions[@]}"; do [[ "$e" == "$fileExtension" ]] && return 0; done
  return 1
}

fail="false"

# just check the files that are modified
for filename in ${FILES}; do
  # echo -e "Checking file $filename"
  shouldCheck "$filename"
  if [[ $? -eq 0 ]]; then
    # we use the current year as the commit date because we are committing now
    # commitDate=$(git log -1 --format="%cd" --date=short -- $filename)
    # commitYear=${commitDate%%-*}

    copyrightYear=$(cat $filename | grep -m1 "Copyright IBM" | sed -En "s/.*Copyright IBM Corp\. ([0-9]+, ){0,1}([0-9]+)\. All Rights Reserved..*$/\2/p")
    if [ -z "${copyrightYear}" ]; then
      echo -e "${RED}Copyright missing in ${filename}${NC}" >&2
      # no need to do anything else
      fail="true"
    else
      copyrightYearCreate=$(cat $filename | grep -m1 "Copyright IBM" | sed -En "s/.*Copyright IBM Corp\. (([0-9]+), ){0,1}([0-9]+)\. All Rights Reserved..*$/\2/p")
      if [ -z "${copyrightYearCreate}" ]; then
        # we can create and then update in the same year
        copyrightYearCreate=$copyrightYear
      else
        # these should not be the same
        if [[ "${copyrightYear}" == "${copyrightYearCreate}" ]]; then
          echo -e "${RED}Copyright needs to be updated for: ${filename}${NC}" >&2
          echo "Created date: ${copyrightYearCreate} should not be the same as the commited date: ${copyrightYear}"
          fail="true"
        fi
      fi
    fi

    if [[ "$fail" == "false" ]]; then
      newfile="false"

      # get the file creation date from git
      creationDate=$(git log --follow --format="%cd" --date=short -- $filename | tail -1)
      if [[ "$creationDate" == "" ]]; then
        # echo -e "${RED}Failed to find creation date for: ${filename}${NC}" >&2
        # this can happen for new files so make the date today
        newfile="true"
        creationDate=${commitDate}
        echo "Set creation date ${creationDate} for ${filename}"
      else
        echo "Found creation date ${creationDate} for ${filename}"
      fi
      creationYear=${creationDate%%-*}

      if [[ "$commitYear" != "$copyrightYear" ]]; then
        echo -e "${RED}Copyright needs to be updated for: ${filename}${NC}" >&2
        echo "Committed: ${commitYear} and written as ${copyrightYear}. Created: ${creationDate} and written as ${copyrightYearCreate}"
        fail="true"
      else
        if [[ "${newfile}" == "false" ]]; then
          if [[ "$creationYear" != "$copyrightYearCreate" ]]; then
            echo -e "${RED}Copyright needs to be updated for: ${filename}${NC}" >&2
            echo "Committed: ${commitYear} and written as ${copyrightYear}. Created: ${creationDate} and written as ${copyrightYearCreate}"
            fail="true"
          fi
        fi
      fi
    fi
  fi
done

if [[ "$fail" == "true" ]]; then
  echo -e "\n${RED}Correct copyrights${NC}"
  exit 1
else
  echo -e "${GREEN}Copyright up to date :)${NC}"
fi
