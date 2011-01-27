#!/usr/bin/python
#
# Copyright (c) 2008 Google Inc. All rights reserved.
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

"""Support functions to enable Python plugins for Quick Search Box.

Much of the interface between the QSB Objective C code and Python
plugins is implemented in the Objective C code. This module contains
additional classes and functions that are able to be implemented in
pure Python.

  AddPathToSysPath(): Adds an additional path to sys.path.
"""

__author__ = 'hawk@google.com (Chris Hawk)'

import os
import sys

def AddPathToSysPath(path_to_add):
  """Adds an additional path to sys.path so that modules in that
  path can be found by subsequent imports.

  Args:
    path_to_add: The path to add

  Returns:
    True if the path was successfully added to sys.path, or is already
    in sys.path
  """
  path_to_add = os.path.abspath(path_to_add)
  add_path = False
  if os.path.exists(path_to_add): # Only add if the path actually exists
    add_path = True
    # Don't add the path if it's already in sys.path
    for path in sys.path:
      path = os.path.abspath(path)
      if path_to_add in (path, path + os.sep):
        return True # already there, handle as if we succeeded
    if add_path:
      sys.path.append(path_to_add)
  return add_path
