//
//  TransferenceClient.h
//
//  Copyright (c) 2009 Google Inc. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are
//  met:
//
//    * Redistributions of source code must retain the above copyright
//  notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above
//  copyright notice, this list of conditions and the following disclaimer
//  in the documentation and/or other materials provided with the
//  distribution.
//    * Neither the name of Google Inc. nor the names of its
//  contributors may be used to endorse or promote products derived from
//  this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
//  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
//  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
//  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
//  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
//  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import <Cocoa/Cocoa.h>
#import "TransferenceProtocol.h"
#import "GTMTransientRootPortProxy.h"

// The TransferenceClient is a framework that any Objective-C application can
// use to connect to a Quick Search Box that has loaded the TransferenceBeacon.
// The client gives access to statistical information collected by the beacon.

@protocol TransferenceClientDelegateProtocol
//  Called when a search is completed by the Quick Search Box.  The caller can
//  choose to call lastSearchTime or moduleSearchTimes to get more information
//  about the search after this delegate is fired.
//
- (void)searchDidComplete;
@end

@interface TransferenceClient : NSObject <TransferenceClientProtocol> {
 @private
  // Object we will get over D.O.
  GTMTransientRootPortProxy<TransferenceServerProtocol> *proxy_;

  __weak id delegate_;  // Object that will implement the delegate methods

  NSString *query_;     // Query term from the last time a search was performed

  NSArray *results_;    // Storage for the results returned from the server

  // Flag if we are still waiting for results to be processed from the server
  BOOL resultsProcessed_; 
}

// Designated initializer. This creates the object and establishes a connection
// to the server.
//
// Args:
//   address - either the host name or IPv4 address of the server as a string.
//   port - port of the server to connect to.
//
// Returns:
//   A TransferenceClient object with a connection established to the server at
//   the given address and port. If the connection cannot be established then
//   nil is returned.  Note: This method performs a protocol version check
//   before returning.  If the version of the client does not match the version
//   of the server, nil will be returned.
//
- (id)initWithAddress:(NSString *)address port:(unsigned short)port;

// Calls the designated initializer using the default Transference port.
//
// Args:
//   address - either the host name or IPv4 address of the server as a string.
//
// Returns:
//   A TransferenceClient object with a connection established to the server at
//   the given address and port. If the connection cannot be established then
//   nil is returned.
//
- (id)initWithAddress:(NSString *)address;

// Convenience initializer for the designated initializer.
//
// Args:
//   address - either the host name or IPv4 address of the server as a string.
//   port - port of the server to connect to.
//
// Returns:
//   A TransferenceClient object with a connection established to the server at
//   the given address and port. If the connection cannot be established then
//   nil is returned.
//
+ (id)clientWithAddress:(NSString *)address port:(unsigned short)port;

// Convenience initializer for the designated initializer using the Transference
// port.
//
// Args: 
//   address - either the host name or IPv4 address of the server as a string.
//   port - port of the server to connect to.
//
// Returns:
//   A TransferenceClient object with a connection established to the server at
//   the given address and port. If the connection cannot be established then
//   nil is returned.
//
+ (id)clientWithAddress:(NSString *)address;

// Convenience initializer for the designated initializer using the default
// Transference address and port.
//
// Args:
//   address - either the host name or IPv4 address of the server as a string.
//   port - port of the server to connect to.
//
// Returns:
//   A TransferenceClient object with a connection established to the server at
//   the default address and port. If the connection cannot be established then
//   nil is returned.
//
+ (id)localClient;

// Returns the startup time for the QSB.
//
// Returns:
//  An NSDate object containing the time when the QSB started up.  The
//  uninitialized value for this is not nil but is the NSDate reference date,
//  1 Janurary 2001
//
- (NSDate *)startupTime;

// Returns the version for the QSB.
//
// Returns:
//  The CFBundleVersion of the QSB
//
- (NSString *)QSBVersion;

// Returns the version of Mac OS X running the QSB
//
// Returns:
//  The version of Mac OS X in the following format: 10.5.3
//
- (NSString *)hostMacOSXVersionString;

// Returns the architecture of the host machine running the QSB as a string.
//
// Returns:
//  A string that can be one of the following: "Intel" or "PowerPC".
//
- (NSString *)hostArchitecture;

// Returns the how long the last search took.
//
// Returns:
//  The amount of time the last completed search took.  If there is a search
//  underway this only returns the last known value.
//
- (NSTimeInterval)lastSearchTime;

// Returns an array of the search results from the last search after they have
// been ranked.  Note: The array returned is an array of dictionaries that have
// the available keys listed in TransferenceProtocol.h.  They all start with
// kResult.
//
// Returns:
//  An array of all of the results from the last completed search in order of
//  rank.
//
- (NSArray *)lastSearchResultsRanked;

// Returns information about each QSB module and how long each one took to
// perform the last search.
//
// Returns:
//  An array of dictionaries.  The dictionaries have the keys:
//  kTransferenceModuleName and kTransferenceModuleTime
//
- (NSArray *)moduleSearchTimes;

// Returns the number of search results.  This function is not faster than using
// lastSearchResults and calling count on the returned array.  This is provided
// as a convenience method if the caller only cares about how many results there
// were and not what they were.
//
// Returns:
//  Number of results from the last completed search.
//
- (NSInteger)numberOfSearchResults;

// Performs a search in QSB asynchronously.
//
// Args:
//  Search query term
//
- (void)performAsynchronousSearch:(NSString *)query;

// Performs a search in QSB synchronously.
//
// Args:
//  Search query term
//
- (void)performSynchronousSearch:(NSString *)query;

// Performs a search for unicode type query in QSB.
//
// Args:
//  Search query term
//
- (void)performSynchronousUnicodeSearch:(NSString *)query;

// List of all plugins loaded and not loaded.  The returned array is an array of
// QSBPlugin objects.  Use the methods of those objects to retrieve and change
// the value of each plugin.
//
// Returns:
//  An array of QSBPlugin objects
//
- (NSArray *)plugins;

// Returns the entire state of the plugins, whether they are enabled or not.
// This data is not meant to be read, but only stored and used to restore those
// settings with setPluginsUsingData:
//
// Returns:
//  The enabled/disabled state of all plugins
//
- (NSData *)pluginsArchive;

// Sets the state of all plugins according to the data passed.  If more plugins
// have been added since the original capture was taken, i.e. the last time
// pluginsArchive was called, the state of the new plugins will not be changed.
//
// Args:
//  Data representing all of the plugins and their state.  This data can be
//  generated by calling pluginsArchive.
//
- (void)setPluginsUsingData:(NSData *)pluginsArchive;

// Subscribes the client to the server.  Doing so means you can implement the
// client delegate methods and they will be called.
//
- (void)subscribeToServer;

// Unsubscribes from the server.  This should be called before disconnecting.
//
- (void)unsubscribeFromServer;

// Sets the delegate for the client.
//
// Args:
//  delegate - reference to the class that will implement the delegate methods
//
- (void)setDelegate:(id)delegate;

// Returns if the client is connected to the beacon.
//
// Returns:
//  YES if connected; NO otherwise
//
- (BOOL)isConnected;
@end

// The QSBPlugin class is used to make updating and retrieving the state of
// plugins easier.  With three getters and setters it simplifies for the client
// the amount of code to be written to manipulate plugins.  The caller should
// never need to create a QSBPlugin object, since the TransferenceClient does
// this under the hood.
//
@interface QSBPlugin : NSObject {
 @private
  NSString *pluginName_;               // Name of the plugin
  BOOL enabled_;                       // State of the plugin
  __weak TransferenceClient *client_;  // Reference to the current client
}

// Returns the name of the plugin.  This is the human readable display name
//
// Returns:
//  The name of the plugin as a string
//
- (NSString *)displayName;

// Returns the enabled state of the plugin.
//
// Returns:
//  YES if the plugin is enabled; NO otherwise
//
- (BOOL)enabled;

// Sets the enabled state of the plugin.  This operation is performed
// immediatley by the beacon.
//
// Args:
//  enabled - the state of the plugin YES for enabled; NO for disabled
//
- (void)setEnabled:(BOOL)enabled;

@end

// The QSBResult class is used to help make getting information about results
// easier.  The caller should never need to create a QSBResult, since the
// TransferenceClient does this under the hood.
@interface QSBResult: NSObject {
 @private
  NSMutableArray *availableActions_;
  NSDictionary *serverData_;
  __weak TransferenceClient *client_;  // Reference to the current client
}

// Returns the display name of the result.  This is the same string that is
// displayed in the QSB UI.
//
// Returns:
//  The name of the result as a string
//
- (NSString *)displayName;

// Returns the display path of the result.  This may be different from what the
// QSB disaplys based on the result.
//
// Returns:
//  The path of the result as a string
//
- (NSString *)displayPath;

// Returns a list of actions that are available for a given result.
//
// Returns:
//  A list of all of the action names that are available as strings
//
- (NSArray *)availableActions;

// Performs the given action.
//
// Args:
//  actionName - the name of the action to be performed.  The action name must
//               exactly match what is returned in availableActions.
//
// Returns:
//  YES if the QSB performs the action; NO otherwise.  Note that if the action
//  takes a long time to be performed a timeout may occur and the result will be
//  NO.  The default time is (kMaxTimeout / 2.0).  It is also important that YES
//  means the QSB returned the appropriate notification indicating the action
//  was performed.
//
- (BOOL)performAction:(NSString *)actionName;

@end
