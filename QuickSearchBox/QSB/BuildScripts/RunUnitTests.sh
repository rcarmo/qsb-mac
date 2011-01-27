#!/bin/sh

# RunUnitTests.sh
#
# Copyright (c) 2007-2009 Google Inc. All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
# 
# * Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above
# copyright notice, this list of conditions and the following disclaimer
# in the documentation and/or other materials provided with the
# distribution.
# * Neither the name of Google Inc. nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


# Build all of our unit tests
# We do it this way instead of using dependencies in the standard xcode model, 
# so we can pass the GTM_DO_NOT_REMOVE_GCOV_DATA flag in and we can unify our
# code coverage numbers.

set -o errexit
set -o nounset
set -o verbose

echo "Test All:${LINENO}: note: Removing gcov data files from ${CONFIGURATION_TEMP_DIR}"
( cd "${CONFIGURATION_TEMP_DIR}" &&  find . -type f -name "*.gcda" -print0 | xargs -0 rm -f )

# Add new test targets here
test_targets=( "Vermilion Test" "QSB Core Test" "Web Bookmarks Test" "Spotlight Files Test" "Clipboard Test" "Shortcuts Test" "CorePlugin Test" )

for test_target in "${test_targets[@]}"; do
  echo "Test All:${LINENO}: note: Testing Target: ${test_target}"
  # '|| true' at the end avoids 'set -o errexit' from exiting this
  # script if xcodebuild returns an error. 
  # Errors from xcodebuild will be logged to the console.
  xcodebuild -project "QSB.xcodeproj" -target "${test_target}" -configuration "${CONFIGURATION}" OBJROOT="${OBJROOT}" SYMROOT="${SYMROOT}" CACHE_ROOT="${CACHE_ROOT}" GTM_DO_NOT_REMOVE_GCOV_DATA=1 || true
  echo "Test All:${LINENO}: note: Done Testing Target: ${test_target}"
done