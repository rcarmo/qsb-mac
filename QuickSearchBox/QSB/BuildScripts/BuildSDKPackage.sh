#!/bin/sh

# BuildSDKPackage.sh
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


# Build SDK Package

set -o errexit
set -o nounset
set -o verbose

echo Building SDK Package

SDK_PACKAGE_DIR="${TEMP_DIR}/QSB SDK"
TEMPLATE_DIR="${SDK_PACKAGE_DIR}/Library/Application Support/Developer/Shared/Xcode/Project Templates/QSB"
PLUGIN_DIR="${SDK_PACKAGE_DIR}/Library/Application Support/Developer/Shared/Xcode/Plug-ins/"
DOCUMENTATION_DIR="${SDK_PACKAGE_DIR}/Library/Developer/Shared/Documentation/DocSets/com.google.qsb.docset"
DOCUMENTATION_CONTENTS_DIR="${DOCUMENTATION_DIR}/Contents"
DOCUMENTATION_RESOURCES_DIR="${DOCUMENTATION_CONTENTS_DIR}/Resources"
DOCUMENTATION_DOCUMENTS_DIR="${DOCUMENTATION_RESOURCES_DIR}/Documents"
INSTALLER_DIR="${TEMP_DIR}/Quick Search Box SDK"
PRODUCT_NAME="Quick Search Box SDK"
PACKAGE_NAME="${PRODUCT_NAME}.pkg"
BUILD_IMAGE_NAME="${CONFIGURATION_BUILD_DIR}/QuickSearchBoxSDK-${GOOGLE_VERSIONINFO_LONG}.${CONFIGURATION}.dmg"

if [ -d "${SDK_PACKAGE_DIR}" ]; then
  rm -Rf  "${SDK_PACKAGE_DIR}"
fi

mkdir -p "${TEMPLATE_DIR}"
mkdir -p "${PLUGIN_DIR}"
mkdir -p "${DOCUMENTATION_DOCUMENTS_DIR}"
mkdir -p "${INSTALLER_DIR}"

ditto "${SRCROOT}/SDK/Templates" "${TEMPLATE_DIR}"
ditto "${SRCROOT}/SDK/Plugins" "${PLUGIN_DIR}"
ditto "${BUILT_PRODUCTS_DIR}/Documentation/Vermilion" "${DOCUMENTATION_DOCUMENTS_DIR}"
cp "${SRCROOT}/SDK/DocumentationResources/Info.plist" "${DOCUMENTATION_CONTENTS_DIR}/Info.plist"
cp "${SRCROOT}/SDK/DocumentationResources/Nodes.xml" "${DOCUMENTATION_RESOURCES_DIR}/Nodes.xml"

# Index documentation
"${SYSTEM_DEVELOPER_BIN_DIR}/docsetutil" index "${DOCUMENTATION_DIR}"

find "${SDK_PACKAGE_DIR}" -name "*.pbxuser" ! -name "default.pbxuser" -exec rm {} \;

chmod -R 755 "${SDK_PACKAGE_DIR}"

"${SYSTEM_DEVELOPER_UTILITIES_DIR}/PackageMaker.app/Contents/MacOS/PackageMaker" -v --root "${SDK_PACKAGE_DIR}" -x "/CVS$" -x "/\.svn$" -x "/\.cvsignore$" -x "/\.cvspass$" -x /"\.DS_Store$" -x "/build$" -x "/*\.mode*" --out "${INSTALLER_DIR}/${PACKAGE_NAME}" -t "${PRODUCT_NAME}" --resources "${SRCROOT}/SDK/PackageResources" --domain system --id "com.google.qsb.sdk.pkg" --version "${GOOGLE_VERSIONINFO_LONG}" --info "${SRCROOT}/SDK/Info.plist" --target 10.4 

pushd "${SRCROOT}/../externals/yoursway-create-dmg"

if [ -f "${BUILD_IMAGE_NAME}" ]
then
  echo Deleting Old SDK Image
  rm "${BUILD_IMAGE_NAME}"
fi

./create-dmg --volname "${PRODUCT_NAME}" --window-pos 128 128 --window-size 256 256 --icon-size 64 --icon "${PACKAGE_NAME}" 128 112 "${CONFIGURATION_BUILD_DIR}/QuickSearchBoxSDK-${GOOGLE_VERSIONINFO_LONG}.${CONFIGURATION}.dmg" "${INSTALLER_DIR}"
popd
