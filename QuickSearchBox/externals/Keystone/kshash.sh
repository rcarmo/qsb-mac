#!/bin/bash
#
#  kshash.sh
#  Keystone
#
#  Created by Greg Miller on 2/4/08.
#  Copyright 2008 Google Inc. All rights reserved.
#
# This script takes a list of files names as arguments and outputs each file's
# base64 encoded SHA-1 hash.
#

PATH=/bin:/usr/bin; export PATH

if [ $# -eq 0 ]; then
  echo "Usage: kshash.sh file1 ..."
  exit 1
fi

for file in "$@"; do
  h=$(openssl sha1 -binary "$file" | openssl base64)
  s=$(stat -f%z "$file")
  printf "%20s:\t%s\t%s\n" "$file" $h $s
done
