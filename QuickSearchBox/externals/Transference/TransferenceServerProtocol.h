//
//  TransferenceServerProtocol.h
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

#import <Foundation/Foundation.h>
#import "TransferenceClientProtocol.h"

@protocol TransferenceServerProtocol

// Returns all of the currently collect stats.
//
// Returns:
//  An NSDictionary that uses the keys defined in TransferenceConstants.h
//
- (bycopy NSDictionary *)generalStats;

// Returns information about the last completed search.
//
// Returns:
//  The NSDictionary has two keys in it:
//    kSearchTime - an NSNumber double that is the time for the search to finish
//    kSearchModuleTimes - an NSArray of dictionaries that have the keys
//                         defined in TransferenceConstants.h
//
- (bycopy NSDictionary *)lastSearchStats;

// Returns an array of the last search results after they have been ranked
//
// Args:
//  client - reference to the client object.  The command returns immediatley,
//           rankedResults:(in bycopy NSArray *)results is called when the
//           results are ready.
//
- (oneway void)lastSearchResultsRanked:(in byref id <TransferenceClientProtocol>)client;

// Returns the number of the results for the previous search
//
// Args:
//  None
//
// Returns:
//  A NSNumber object with the number of results we got for the previous query
//
- (in bycopy NSNumber *)numberOfResults;

// Performs the passed action on the passed result.
//
// Args:
//  actionName - the name of the action to be performed as a string.
//  dict - a copy of the client data sent to the client.  This data would be
//         one of the items in the array sent when the client called
//         lastSearchResults or lastSearchResultsRanked.
//
// Returns:
//  YES if the action was performed; NO otherwise
//
- (in bycopy NSNumber *)performAction:(NSString *)actionName
                             onResult:(NSDictionary *)dict;

// Returns an array of all plugins those that are loaded and those that are not.
// Every time this is called the list is refreshed with the latest data.  While
// the array is a list of dictionaries the client will take this and turn it
// into a more convenient interface on the other side.
//
// Returns:
//  An array of all plugins.  The array is an array of dictionaries the keys for
//  the dictionary can be found in TransferenceConstants.h and begin with
//  kPlugin...
//
- (in bycopy NSArray *)plugins;

// Returns the server version number.  If the version number of the client does
// not match the version number returned, it is strongly recommended that both
// the client and server are upgraded.
// Note: If you use TransferenceClient it will disconnect from the client if
// the client and server version numbers are not equal.
//
// Returns:
//  The version number of the server.
//
- (in bycopy NSNumber *)serverVersionNumber;

// Sets the state of the plugin with the given name.  If multiple plugins have
// the same name all of them are set to the given state.  The list of plugins
// is refreshed before the state changed is applied.
//
// Args:
//  state - the state of the plugin as a boolean
//  pluginName - the name of the plugin, case sensitive
//
- (void)setState:(NSNumber *)state forPlugin:(NSString *)pluginName;

// Registers the the client with the server.  This is only required if the
// client wants to receive notifications from the server.  Any client can
// connect and query for data directly.
//
// Args:
//  newClient - reference to the client object
//
- (void)subscribeClient:(in byref id <TransferenceClientProtocol>)newClient;

// Unregisters the passed client with the server.
//
// Args:
//  client - reference to the client object to be removed
//
- (void)unsubscribeClient:(in byref id <TransferenceClientProtocol>)client;
@end
