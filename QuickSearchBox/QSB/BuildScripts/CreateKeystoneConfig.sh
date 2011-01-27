#!/bin/bash
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
#
#  Creates up our Keystone config
#

set -o errexit
set -o nounset
set -o verbose

# work in the output dir
cd "${TARGET_BUILD_DIR}" || exit 1

omaha_cfg=autoupdate-ascii-quicksearch.config
omaha_cfg_template="${SOURCE_ROOT}/../externals/Keystone/${omaha_cfg}"
dmg_name="QuickSearchBox-${GOOGLE_VERSIONINFO_LONG}.${CONFIGURATION}.dmg"

dmg_path="${BUILT_PRODUCTS_DIR}/${dmg_name}"

release_notes_name=$(basename "${QSB_RELEASE_NOTE_PATH}")

# Make sure everything we need exists
test -r "${omaha_cfg_template}" || exit 2
test -r "${dmg_path}" || exit 3

d=$(date +%Y-%m-%d)
h=$("${SRCROOT}/../externals/Keystone/kshash.sh" "${dmg_path}" | awk '{print $2}')
s=$(stat -f%z "${dmg_path}")

v="${GOOGLE_VERSIONINFO_LONG}"
cn="${QSB_CODE_NAME}"
bundle_id="${QSB_BUNDLE_ID}"

cat "${omaha_cfg_template}" > "${omaha_cfg}"
perl -p -i -e "s,<DMG_NAME>,$dmg_name,g" "${omaha_cfg}"
perl -p -i -e "s,<RELEASE_NOTES_NAME>,$release_notes_name,g" "${omaha_cfg}"
perl -p -i -e "s,<VERSION>,$v,g" "${omaha_cfg}"
perl -p -i -e "s,<DATE>,$d,g" "${omaha_cfg}"
perl -p -i -e "s,<HASH>,$h,g" "${omaha_cfg}"
perl -p -i -e "s,<SIZE>,$s,g" "${omaha_cfg}"
perl -p -i -e "s,<CODE_NAME>,$cn,g" "${omaha_cfg}"
perl -p -i -e "s,<BUNDLE_ID>,$bundle_id,g" "${omaha_cfg}"