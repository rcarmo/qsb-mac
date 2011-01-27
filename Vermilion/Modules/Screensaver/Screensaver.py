#!/usr/bin/python
#
# Copyright 2009 Google Inc. All Rights Reserved.

"""A Google Quick Search plugin for Mac OS X screensavers.

Given a user's Quick Search Box query, this search source
retrieves and returns screensavers matching the query.

  Screensaver: The core search source class.
  SetScreensaverAction: QSB action to set the screensaver.
"""

import copy
import os
import sys
import thread
import time
import traceback
import urllib
from datetime import datetime

try:
  import Vermilion
except ImportError:
  class Vermilion(object):
    """A mock implementation of the Vermilion class.

    Vermilion is provided in native code by the QSB
    runtime. We create a stub Result class here so that we
    can develop and test outside of QSB from the command line.
    """
    
    IDENTIFIER = 'IDENTIFIER'
    DISPLAY_NAME = 'DISPLAY_NAME'
    MAIN_ITEM = 'MAIN_ITEM'
    OTHER_ITEMS = 'OTHER_ITEMS'
    SNIPPET = 'SNIPPET'
    IMAGE = 'IMAGE'
    DEFAULT_ACTION = 'DEFAULT_ACTION'
    TYPE = 'TYPE'

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

MIN_QUERY_LENGTH = 3
DEFAULT_ACTION = "com.google.qsb.screensavers.action.set"
SCREEN_SAVER_TYPE = "script.python.screensaver"
debugging_is_enabled = False

class ScreensaverBase(object):
  """Shared base class for the screensaver source and action.

  This class simply maintains a list of screensavers from known
  locations in the filesystem, indexing them at startup.
  """

  def __init__(self, extension=None):
    """Initializes the plugin.
    
    Initializes the plugin by indexing the various screen saver
    folders. While we index everything here at launch time, the 
    plugin could be enhanced by periodically re-indexing or
    watching the folders for changes to catch newly added
    screen saver bundles.
    
    We look in three places for screen saver bundles:
      /System/Library/Screen Savers
      /Library/Screen Savers
      ~/Library/Screen Savers
    
    We identify the screen savers in these folders by looking for
    the bundle extensions ".slideSaver", ".saver", and ".qtz". We'll
    save each of the screen saver names in a dictionary, with the name
    converted to lower-case so that we can do quick case-insensitive
    matching when we receive queries.

    Args:
      extension: An opaque instance of the extension.
    """
    self.extension = extension
    self.folders = [
      "/System/Library/Screen Savers",
      "/Library/Screen Savers",
      "%s/Library/Screen Savers" % os.environ["HOME"]
    ]
    self.extensions = [
      ".slideSaver",
      ".saver",
      ".qtz"
    ]
    self._savers = {}
    for folder in self.folders:
      if os.path.isdir(folder):
        bundles = os.listdir(folder)
        for bundle in bundles:
          for extension in self.extensions:
            if bundle.endswith(extension) and len(bundle) > len(extension):
              name = bundle[0:len(bundle) - len(extension)]
              self._savers[name.lower()] = "%s/%s" % (folder, bundle), name

  def SaverForPath(self, path):
    """Returns a tuple of (path, name) of the indexed screensaver.
    
    Returns a tuple of (path, name) of the indexed screensaver, or
    None if the screensaver cannot be found.
    
    Args:
      path: The input path may be either an absolute path or a file:// URL,
          but the returned path is always the absolute path the screensaver.
    """
    if debugging_is_enabled:
      print "Checking path '%s' to see if it is a screensaver." % path
    if path.startswith("file://localhost"):
      path = urllib.unquote(path[16:])
    if path.startswith("file://"):
      path = urllib.unquote(path[7:])
    name = os.path.basename(path)
    for extension in self.extensions:
      if name.endswith(extension) and len(name) > len(extension):
        name = name[0:len(name) - len(extension)]
        key = name.lower()
        if self._savers.has_key(key):
          if debugging_is_enabled:
            print "Path was screensaver; given key: '%s'" % key
          return self._savers[key]
    if debugging_is_enabled:
      print "Didn't find screensaver at path: '%s'" % path
    return None

  def IsScreensaver(self, path):
    """Does the path point to a screen saver.
    
    Returns a boolean value indicating whether or not the given
    path points to one of our indexed screensavers.
    
    Args:
      path: The input path may be either an absolute path or a file:// URL.
    
    Returns:
      True if the path resolves to a screensaver, otherwise False.
    """
    return self.SaverForPath(path) != None


class Screensaver(ScreensaverBase):
  """The screen saver search source.

  This class conforms to the search source protocol by
  providing the mandatory PerformSearch method and the optional
  IsValidSourceForQuery method.
  """

  def __init__(self, extension=None):
    super(Screensaver, self).__init__(extension)

  def PerformSearch(self, query):
    """Searches for screensavers

    Args:
      query: A Vermilion.Query object containing the user's search query
  
    Returns:
      A list of zero or more dictionaries representing the search
      results. There are several mandatory key/value pairs that every
      result must contain, and each search source can include additional
      values that may be used for later pivots and actions. For example:
  
      {
        Vermilion.IDENTIFIER: 'file:///Users/jane/file.txt',
        Vermilion.SNIPPET: 'Some text file contents',
        'MyProprietaryKey': 'Some useful information'
      }
    """
    try:
      results = []
      term = query.normalized_query
      if debugging_is_enabled:
        print "PerformSearch for query with term: %s" % term
      if query.pivot_object is not None:
          for key in self._savers.iterkeys():
            if len(term) == 0 or key.startswith(term):
              results.append(self.CreateResult(self._savers[key]))
      else:
        # If the user is searching for "screen saver" or "screensaver",
        # return all of the screen savers
        screensaver = VermilionLocalize.String("screensaver", self.extension)
        screen_saver = VermilionLocalize.String("screen saver", self.extension)
        raw_query = query.raw_query.lower()
        if (screensaver.startswith(raw_query) or
            screen_saver.startswith(raw_query)):
          for key in self._savers.iterkeys():
            results.append(self.CreateResult(self._savers[key]))
        else:
          # Otherwise, return screen savers whose names match the query
          for key in self._savers.iterkeys():
            if key.startswith(term):
              results.append(self.CreateResult(self._savers[key]))
      query.SetResults(results)
    except Exception, exception:
      # Catch everything to make sure that we never pass up the
      # call to query.Finish()
      if debugging_is_enabled:
        print "An exception was thrown. %s" % exception
        traceback.print_exc()
      pass
    if debugging_is_enabled:
      print "PerformSearch gave results: %s" % results
    query.Finish()

  def IsValidSourceForQuery(self, query):
    """Determines if the screen saver search source is willing to
    handle the query. For example purposes, we check to see if the
    query meets our minimum length requirements (three characters), or
    if we are pivoting off a previous screen saver result.

    Args:
      query: A Vermilion.Query object containing the user's search query
  
    Returns:
      True if the pivot object is one of our own results from a previous
      query, or if this is a non-pivot query of three characters or more.
    """
    pivot_object = query.pivot_object
    # Can we pivot?
    if pivot_object is not None:
      return self.IsScreensaver(pivot_object[Vermilion.IDENTIFIER])
    # Does the non-pivot query meet our minimum length standard?
    return len(query.normalized_query) >= MIN_QUERY_LENGTH

  def CreateResult(self, entry):
    result = {}
    path, name = entry
    format = VermilionLocalize.String("%s Screen Saver", self.extension)
    screensaver = VermilionLocalize.String("screensaver", self.extension)
    screen_saver = VermilionLocalize.String("screen saver", self.extension)
    result[Vermilion.IDENTIFIER] = "file://%s" % urllib.quote(path)
    result[Vermilion.DISPLAY_NAME] = format % name
    result[Vermilion.TYPE] = SCREEN_SAVER_TYPE
    result[Vermilion.MAIN_ITEM] = name
    result[Vermilion.OTHER_ITEMS] = '%s %s' % (screensaver, screen_saver)

    return result

class SetScreensaverAction(ScreensaverBase):
  """QSB action class that sets the screensaver.

  This class conforms to the QSB search action protocol by
  providing the mandatory AppliesToResults and Perform methods.
  """

  def __init__(self, extension=None):
    super(SetScreensaverAction, self).__init__(extension)
    
  def AppliesToResults(self, results):  
    """Determine the applicability of the result for the action.
    
    Determines if the result is one returned by our search source by
    verifying that our search result identifier points to one of our
    indexed screen savers.
    
    Args:
      results: An array of result objects for which to determine the
          action's applicability.

    Returns:
      A boolean indicating if the action is appropriate for ALL of the
      results contained in the results array.
    """
    for result in results:
      return self.IsScreensaver(result[Vermilion.IDENTIFIER])
    return False

  def Perform(self, results, indirect_objects=None):
    """Set the screen saver.
    
    Sets the selected screen saver as the user's current screen saver
    by using the "defaults" command line tool.

    Args:
      results: An array of result objects for with which to perform the action.
      indirect_objects: The indirect object associated with the action.
    """
    for result in results:
      path, name = self.SaverForPath(result[Vermilion.IDENTIFIER])
      if path and name:
        cmd = ('defaults -currentHost write com.apple.screensaver moduleName '
               '-string "%s"') % name
        if os.system(cmd):
          print 'screensaver action (%s) failed' % cmd
          return False
        cmd = ('defaults -currentHost write com.apple.screensaver modulePath '
               '-string "%s"') % path
        if os.system(cmd):
          print 'screensaver action (%s) failed' % cmd
          return False
        return True
    return False


def main(argv=None):
  """Command line interface for easier testing."""
  global debugging_is_enabled
  if argv is None:
    argv = sys.argv[1:]

  if len(argv) < 1:
    print 'Usage: Screensaver <query> [-d]'
    return 1
  
  if argv[1:].count('-d'):
    debugging_is_enabled = True

  query = Vermilion.Query(argv[0])
  search = Screensaver()
  if not search.IsValidSourceForQuery(Vermilion.Query(argv[0])):
    print 'Not a valid query'
    return 1
  search.PerformSearch(query)
  
  while query.finished is False:
    time.sleep(1)

  for result in query.results:
    if debugging_is_enabled:
      print "Result: %s." % result
    else:
      print result


if __name__ == '__main__':
  sys.exit(main())
