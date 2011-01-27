#!/bin/bash
#
# CreateDiskImages.sh
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
#
#  Creates our disk images for QSB and Transference.
#  Disk image for the SDK is created in BuildSDKPackage.sh 
#

set -o errexit
set -o nounset
set -o verbose

QSB_NAME="Quick Search Box"
QSB_NEW_DIR="${DERIVED_FILES_DIR}/${QSB_NAME}"
QSB_NEW_FILE="${BUILT_PRODUCTS_DIR}/QuickSearchBox-${GOOGLE_VERSIONINFO_LONG}.${CONFIGURATION}.dmg"
QSB_APP_NAME="${QSB_NAME}.app"
QSB_INSTALLER_SOURCES="${SRCROOT}/installer"

if [ -f "${QSB_NEW_FILE}" ]
then
  rm "${QSB_NEW_FILE}"
fi

mkdir -p "${QSB_NEW_DIR}"
ditto "${BUILT_PRODUCTS_DIR}/${QSB_APP_NAME}" "${QSB_NEW_DIR}/${QSB_APP_NAME}"

ditto "${QSB_INSTALLER_SOURCES}/keystone_preinstall" "${QSB_NEW_DIR}/.keystone_preinstall"
ditto "${QSB_INSTALLER_SOURCES}/keystone_install" "${QSB_NEW_DIR}/.keystone_install"
ditto "${QSB_INSTALLER_SOURCES}/keystone_postinstall" "${QSB_NEW_DIR}/.keystone_postinstall"
chmod 755 "${QSB_NEW_DIR}/.keystone_preinstall"
chmod 755 "${QSB_NEW_DIR}/.keystone_install"
chmod 755 "${QSB_NEW_DIR}/.keystone_postinstall"

pushd "${SRCROOT}/../externals/yoursway-create-dmg"
./create-dmg --volname "${QSB_NAME}" --window-pos 128 128 --window-size 256 256 --icon-size 64 --icon "${QSB_APP_NAME}" 128 112 "${QSB_NEW_FILE}" "${QSB_NEW_DIR}"
popd

TRANSFERENCE_NAME="TransferenceBeacon"
TRANSFERENCE_NEW_DIR="${DERIVED_FILES_DIR}/${TRANSFERENCE_NAME}"
TRANSFERENCE_NEW_FILE="${BUILT_PRODUCTS_DIR}/${TRANSFERENCE_NAME}-${GOOGLE_VERSIONINFO_LONG}.${CONFIGURATION}.dmg"
TRANSFERENCE_PLUGIN="${TRANSFERENCE_NAME}.hgs"
TRANSFERENCE_DEMO="Transference Demo.app"

if [ -f "${TRANSFERENCE_NEW_FILE}" ]
then
  rm "${TRANSFERENCE_NEW_FILE}"
fi

mkdir -p "${TRANSFERENCE_NEW_DIR}"
ditto "${BUILT_PRODUCTS_DIR}/${TRANSFERENCE_PLUGIN}" "${TRANSFERENCE_NEW_DIR}/${TRANSFERENCE_PLUGIN}"
ditto "${BUILT_PRODUCTS_DIR}/${TRANSFERENCE_DEMO}" "${TRANSFERENCE_NEW_DIR}/${TRANSFERENCE_DEMO}"

pushd "${SRCROOT}/../externals/yoursway-create-dmg"
./create-dmg --volname "${TRANSFERENCE_NAME}" --window-pos 128 128 --window-size 384 192 --icon-size 64 "${TRANSFERENCE_NEW_FILE}" "${TRANSFERENCE_NEW_DIR}"
popd
