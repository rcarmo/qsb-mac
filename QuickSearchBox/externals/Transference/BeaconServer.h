//
//  BeaconServer.h
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
#import "GTMAbstractDOListener.h"
#import "TransferenceProtocol.h"

// Needed for HGSObject/HGSModule
#import <Vermilion/Vermilion.h>

// All delegates must implement the following protocol to perform plugin actions
@protocol BeaconServerProtocol
// Refreshes the current plugins
//
- (void)refreshPlugins;

// Updates the plugin specificed by pluginInfo within the QSB.  The is done
// immediatley.
//
- (void)updatePlugin:(NSDictionary *)pluginInfo;
@end


@interface BeaconServer : GTMAbstractDOListener <TransferenceServerProtocol> {
 @private
  NSDate *startupTime_;           // Stores all of the stats we care about.
  NSDictionary *generalStats_;    // Contains the general stats information
  NSMutableArray *clients_;       // list of all of the connected clients
  NSMutableDictionary *lastSearchStats_;  // Contains info about the last search

  // Contains the ranked results from the last search
  NSArray *lastSearchResultsRanked_;
  NSArray *plugins_;              // List of all plugins loaded by QSB
  __weak id delegate_;
  BOOL actionWillBePerformed_;    // Flag set when the QSB performs an action
}

@property(nonatomic, assign) id delegate;
@property(nonatomic, readwrite, retain) NSDate *startupTime;

// Designated initializer.  If init is called it will call this with the default
// kTransferencePort.  socket must be valid.
//
// Args:
//  socket - the port to listen on
//
// Returns:
//  A BeaconServer if successful.  If the socket is invalid or an unforseen
//  error is encountered nil will be returned.
//
- (id)initWithSocket:(NSSocketPort *)listenSocket;

//
// Setters for QSB statistical information
//

// Sets the list of plugins.
//
// Args:
//  plugins - the list of plugins
//
- (void)setPlugins:(NSArray *)plugins;

// Sets how long the last search took to complete
//
// Args:
//  time - how long the last search took
//  info - an array of each module and how long the search time took.  this
//         argument should be an array of dictionaries.  The dictionaries
//         should have the following keys (defined in TransferenceConstants.h)
//         kTransferenceModuleName and kTransferenceModuleTime
//
- (void)setLastSearchTime:(NSTimeInterval)searchTime moduleInfo:(NSArray *)info;

// Sets the last search results that are ranked
//
// Args:
//  results - array of the last search results after they are ranked
//
- (void)setLastRankedResults:(NSArray *)results;
@end
