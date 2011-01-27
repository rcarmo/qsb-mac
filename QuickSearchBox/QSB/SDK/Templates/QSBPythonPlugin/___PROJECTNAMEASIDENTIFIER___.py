#!/usr/bin/python
#
#  ___PROJECTNAMEASIDENTIFIER___.py
#  ___PROJECTNAME___
#
#  Created by ___FULLUSERNAME___ on ___DATE___.
#  Copyright ___ORGANIZATIONNAME___ ___YEAR___. All rights reserved.
#

"""A python search source for QSB.
"""

__author__ = '___FULLUSERNAME___'

import sys
import thread
import AppKit
import Foundation

try:
  import Vermilion  # pylint: disable-msg=C6204
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
      """A mock implementation of the Vermilion.Query class.

      Vermilion is provided in native code by the QSB
      runtime. We create a stub Result class here so that we
      can develop and test outside of QSB from the command line.
      """
      
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
    
    When this source is called from QSB, i.e. when not being run from the
    command line, user-visible strings can be localized by making a call
    like:
    
      localized_string = VermilionLocalize.String(raw_string, self.extension)
    
    The localization version of all strings to be localized in this plugin
    must be provided in the appropriate Localizable.strings file in the
    plugin's bindle.
    """	

    def String(self, string, extension):	
      return string
  
  VermilionLocalize = VermilionLocalizeStubClass()

CUSTOM_RESULT_VALUE = 'CUSTOM_RESULT_VALUE'
debugging_is_enabled = False

class ___PROJECTNAMEASIDENTIFIER___Search(object):
  """___PROJECTNAMEASIDENTIFIER___ search source.

  This class conforms to the QSB search source protocol by
  providing the mandatory PerformSearch method and the optional
  IsValidSourceForQuery method.

  """

  def __init__(self, extension=None):
    """Initializes the plugin.

    Args:
      extension: An opaque instance of the extension.
    """
    self.extension = extension

  def PerformSearch(self, query):
    """Performs the search.
    
    Perform the search using the query string provided in the argument.  In
    this template the search is performed on the main thread. If the search
    is expected to take a significant amount of time then consider having
    PerformSearch spin off a thread. See StockQuoter.py for an example of
    how this might be done.

    Args:
      query: A Vermilion.Query object containing the user's search query
    """
    if debugging_is_enabled:
      print "PerformSearch with query: '%s'." % query
    try:
      # When a search successfully finds some results those results are returned
      # in the |query| object as an array. In this case, |results|.
      results = [];
      result = {};
      result[Vermilion.IDENTIFIER] = '___PROJECTNAMEASIDENTIFIER___://result';
      result[Vermilion.SNIPPET] = 'So here\'s a bunny with a pancake on it\'s head!';
      result[Vermilion.IMAGE] = '___PROJECTNAMEASIDENTIFIER___.png';
      result[Vermilion.DISPLAY_NAME] = '___PROJECTNAMEASIDENTIFIER___ Result';
      result[Vermilion.DEFAULT_ACTION] = 'com.yourcompany.action.___PROJECTNAMEASIDENTIFIER___';
      result[CUSTOM_RESULT_VALUE] = 'http://www.fsinet.or.jp/~sokaisha/rabbit/rabbit.htm';
      # Each individual result is appended to the array of results.
      results.append(result);
      # Once collected, set the final array of results into the query using
      # the SetResults method.
      query.SetResults(results)
    except Exception, exception:
      # Catch everything to make sure that we never miss calling query.Finish()
      if debugging_is_enabled:
        print "An exception was thrown. %s" % exception
        traceback.print_exc()
      pass
    # The query's Finish method must always be called, even if there were no
    # results or when some exceptional error arose.
    query.Finish()

  def IsValidSourceForQuery(self, query):
    """Determines if the search source is willing to handle the query.

    Args:
      query: A Vermilion.Query object containing the user's search query

    Returns:
      True if this source can handle the query
    """
    return True

  def UpdateResult(self, result):
    """Determine if new or updated attributes should be added to a result.
    
    Do not implement this function unless necessary. This function is called
    indirectly via [HGSPythonSource resultWithArchivedRepresentation:].
    
    Args:
      result: The result which we are to analyze for updating.
    
    Returns:
      A dictionary of attributes which are to be replaced or added to the
      result, if any, otherwise return None to indicate the result is okay
      as-is. If the result is okay as-is then return None. One would
      typically use attribute keys as defined in HGSResult.h with
      appropriately typed values though at the current time we only
      support strings.
    """
    return None

    
class ___PROJECTNAMEASIDENTIFIER___Action(object):
  """___PROJECTNAMEASIDENTIFIER___ Action

  This class conforms to the QSB search action protocol by
  providing the mandatory AppliesToResults and Perform methods.
  
  """
  def AppliesToResults(self, result):
    """Determine if the action applies to the results.

    Args:
      result: An array of result objects for which to determine the
        action's applicability.

    Returns:
      A boolean indicating if the action is appropriate for ALL of the
      results contained in the results array.
    """
    return True

  def Perform(self, direct_objects, other_arguments=None):
    """Perform the action on each of the results.
    
    Args:
      direct_objects: An array of result objects to perform the action with.
      other_arguments: A dictionary of other arguments keyed by argument id.

    Returns:
      If this action returns results, an array of results on success. Otherwise
      return True on success, and False on failure.
    """
    for direct_object in direct_objects:
      url = Foundation.NSURL.URLWithString_(direct_object[CUSTOM_RESULT_VALUE])
      workspace = AppKit.NSWorkspace.sharedWorkspace()
      workspace.openURL_(url)
    return True


def main():
  """Command line interface for easier testing.
  
  Command line args:
    <query>: A string, in quotes if multiple words, specifying the query term.
    -d: An optional flag indicating that debugging output should be generated.
        When specified, the global variable debugging_is_enabled is set to
        True and can be used throughout the code for controlling debug code.
  """
  argv = sys.argv[1:]
  if not argv:
    print 'Usage: ___PROJECTNAMEASIDENTIFIER___ <query> [-d]'
    return 1

  if argv[1:].count('-d'):
    debugging_is_enabled = True

  query = Vermilion.Query(argv[0])
  search = ___PROJECTNAMEASIDENTIFIER___Search()
  if not search.IsValidSourceForQuery(Vermilion.Query(argv[0])):
    print 'Not a valid query'
    return 1
  search.PerformSearch(query)

  while query.finished is False:
    time.sleep(1)

  for result in query.results:
    # Debug statements can be liberally spread throughout the code and
    # conditionalized on debugging_is_enabled.
    if debugging_is_enabled:
      print "Result: %s." % result
    else:
      print result


if __name__ == '__main__':
  sys.exit(main())
