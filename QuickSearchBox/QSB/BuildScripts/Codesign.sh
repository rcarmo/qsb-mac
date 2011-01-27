#!/bin/sh

# Codesign.sh
#
# Copyright 2010 Google Inc. All rights reserved.
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

set -o errexit
set -o verbose

# If we are not running in a signing environment, don't even attempt to sign
if [[ -z "$GOOGLE_CODE_SIGN_IDENTITY" ]]; then
  exit 0
fi

signingApp="/usr/bin/codesign"
codeSigningIdentity=${GOOGLE_CODE_SIGN_IDENTITY}
codeSigningOtherFlags=${GOOGLE_OTHER_CODE_SIGN_FLAGS}

externalApplication="${BUILT_PRODUCTS_DIR}/Quick Search Box.app"
externalVermilion="${externalApplication}/Contents/Frameworks/Vermilion.framework/Versions/A"
transferenceBundle="${BUILT_PRODUCTS_DIR}/TransferenceBeacon.hgs"

# Sign the plug-ins
for app in "${externalApplication}"
do
  for plugin in "${app}"/Contents/PlugIns/*.hgs
  do
    # For Python plugins, make the Resources directory non-writable to
    # prevent .pyc files from being written and breaking the signature
    if ls "${plugin}"/Contents/Resources/*.py >/dev/null 2>&1 ; then
      chmod a-w "${plugin}/Contents/Resources"
    fi
    "${signingApp}" -f -s "${codeSigningIdentity}" ${codeSigningOtherFlags} "${plugin}"
  done
done

# As with Python plugins, lock down the Resources folder of Vermilion.framework,
# which contains some Python scripts
chmod a-w "${externalVermilion}/Resources"

# Sign the applications
"${signingApp}" -f -s "${codeSigningIdentity}" ${codeSigningOtherFlags} "${externalVermilion}"
"${signingApp}" -f -s "${codeSigningIdentity}" ${codeSigningOtherFlags} "${externalApplication}"
"${signingApp}" -f -s "${codeSigningIdentity}" ${codeSigningOtherFlags} "${transferenceBundle}"

# Warn if we failed to create the signature
if [ $? -ne 0 ]; then
  echo error: Did not perform code signing, make sure you have a "${codeSigningIdentity}" code signing certificate in the appropriate keychain
fi
