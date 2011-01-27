#!/bin/sh
#
# StripHeaders.sh
#
# Copyright 2007-2008 Google Inc. All rights reserved.

set -o errexit
set -o nounset
set -o verbose

# Strip "*.h" files
find "${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}" -iname '*.h' -delete

# Strip "Headers" links
find "${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}" -iname 'Headers' -type l -delete

# Strip "Headers" directories
find "${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}" -iname 'Headers' -type d -prune -delete


