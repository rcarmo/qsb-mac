#
#  VermilionTest.py
#
#  Copyright (c) 2009 Google Inc. All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions are
#  met:
#
#    * Redistributions of source code must retain the above copyright
#  notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above
#  copyright notice, this list of conditions and the following disclaimer
#  in the documentation and/or other materials provided with the
#  distribution.
#    * Neither the name of Google Inc. nor the names of its
#  contributors may be used to endorse or promote products derived from
#  this software without specific prior written permission.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
#  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
#  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
#  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
#  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
#  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
#  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
#  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

import copy
import os
import sys
import thread
import time
import urllib
from datetime import datetime

try:
  import Vermilion
  import VermilionNotify
except ImportError:
  # Vermilion is provided in native code by the Quick Search
  # runtime. Create a stub Result class here so that we
  # can develop and test outside of Quick Search
  class Vermilion(object):
    IDENTIFIER = 'IDENTIFIER'
    DISPLAY_NAME = 'DISPLAY_NAME'
    SNIPPET = 'SNIPPET'
    IMAGE = 'IMAGE'
    TYPE = 'TYPE'
    DEFAULT_ACTION = "DEFAULT_ACTION"
    class Query(object):
      def __init__(self, phrase):
        self.raw_query = phrase
        self.normalized_query = phrase
        self.pivot_object = None
        self.finished = False
        self.results = []
      def SetResults(self, results):
        self.results = results
      def Finish(self):
        self.finished = True

try:
  import VermilionLocalize
except ImportError:
  class VermilionLocalizeStubClass(object):	
    """Stub class used when running from the command line.	

    Required when this script is run outside of the Quick Search Box.  This	
    class is not needed when Vermilion is provided in native code by the	
    Quick Search runtime.	
    """	

    def String(self, string, extension):	
      return string
  
  VermilionLocalize = VermilionLocalizeStubClass()


class VermilionTest(object):

  def __init__(self, extension=None):
    self.extension = extension              

  def PerformSearch(self, query):
    try:
      results = []
      result = {}
      result[Vermilion.IDENTIFIER] = "file:///dev/null"
      result[Vermilion.DISPLAY_NAME] = "%s Result" % query.normalized_query
      result[Vermilion.TYPE] = "python.test.type"
      result[Vermilion.SNIPPET] = VermilionLocalize.String("Localized Value",
                                                           self.extension)
      result[Vermilion.MAIN_ITEM] = query.normalized_query
      result[Vermilion.OTHER_ITEMS] = ""
      result["CustomKey"] = "CustomValue"
      results.append(result)
      query.SetResults(results)
    except:
      # Catch everything to make sure that we never pass up the
      # call to query.Finish()
      pass
    query.Finish()

  def IsValidSourceForQuery(self, query):
    return True


class VermilionAction(object):

  def __init__(self, extension=None):
    self.extension = extension
    
  def AppliesToResults(self, result):
    return True

  def Perform(self, result, pivot_object=None):
    VermilionNotify.DisplayNotification("Message", self.extension);
    VermilionNotify.DisplayNotification("Message", self.extension,
                                        "Description");
    VermilionNotify.DisplayNotification("Message", self.extension,
                                        "Description", "Name");
    return True


def main(argv=None):
  """Command line interface for easier testing."""
  if argv is None:
    argv = sys.argv[1:]

  if len(argv) < 1:
    print 'Usage: VermilionTest <query>'
    return 1
  
  query = Vermilion.Query(argv[0])
  search = VermilionTest()
  if not search.IsValidSourceForQuery(Vermilion.Query(argv[0])):
    print 'Not a valid query'
    return 1
  search.PerformSearch(query)
  
  while query.finished is False:
    time.sleep(1)

  for result in query.results:
    print result


if __name__ == '__main__':
  sys.exit(main())
