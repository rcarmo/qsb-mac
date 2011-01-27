//
//  TransferenceBeaconModule.m
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

#import "BeaconServer.h"
#import <GTM/GTMTypeCasting.h>

NSString *const kUnknownPluginIdentifier = @"Unknown Plugin Identitifer";

@interface TransferenceBeaconModule : HGSExtension <BeaconServerProtocol> {
 @private
  NSDate *startSearchDate_;
  NSDate *endSearchDate_;

  NSMutableArray *startedSearchSources_;
  NSMutableArray *completedSearchSources_;
  BeaconServer *server_;
}
// Strips the source string description to make it more human readable.
//
- (NSDictionary *)searchSourceDictionaryForObject:(id)searchObject;
- (void)pluginsDidInstall:(NSNotification *)aNotification;
- (void)HGSQueryControllerWillStart:(NSNotification *)aNotification;
- (void)HGSQueryControllerDidFinish:(NSNotification *)aNotification;
- (void)HGSSearchOperationWillStart:(NSNotification *)aNotification;
- (void)HGSSearchOperationDidFinish:(NSNotification *)aNotification;
@end

@implementation TransferenceBeaconModule

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
    NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
    [noteCenter addObserver:self
                   selector:@selector(pluginsDidInstall:)
                       name:kHGSPluginLoaderDidInstallPluginsNotification
                     object:nil];

    // Allocate for the searchObject array
    startedSearchSources_ = [[NSMutableArray alloc] init];
    completedSearchSources_ = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)dealloc {
  // Remove ourselves from receiving notifications
  NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
  [noteCenter removeObserver:self];

  // Shutdown the server
  [server_ shutdown];
  [server_ release];

  // Statistical data
  [startedSearchSources_ release];
  [completedSearchSources_ release];
  [startSearchDate_ release];
  [endSearchDate_ release];

  [super dealloc];
}

#pragma mark -- Private Methods --
- (NSDictionary *)searchSourceDictionaryForObject:(id)searchObject; {
  NSDictionary *dict = nil;
  if ([searchObject isKindOfClass:[HGSSearchOperation class]]) {
    HGSSearchSource *source = (HGSSearchSource *)[searchObject source];
    NSString *searchObjectClass = [source valueForKey:@"identifier_"];
    // In order to tabulate the times we need the identifier of the plugin.
    // Also the plugin names need to be unique.  If a plugin doesn't have an
    // identifier, there is nothing we can do so we don't process it.
    if (searchObjectClass) {
      NSDate *date = [NSDate date];
      dict = [NSDictionary dictionaryWithObjectsAndKeys:searchObjectClass,
              kTransferenceModuleName, date, kTransferenceModuleTime, nil];
    } else {
      HGSLog(@"TransferenceBeacon: encountered a search source that does not "
             @"implement identifier_.  Unable to generate performance timing "
             @"for this source.");
    }
  }
  return dict;
}

#pragma mark -- BeaconServer delegate methods --

- (void)refreshPlugins {
  // Collect information about all of the loaded plugins
  NSMutableArray *allPlugins = [NSMutableArray array];
  NSArray *sources = [[HGSExtensionPoint pluginsPoint] extensions];
  for (HGSPlugin *plugin in sources) {
    NSArray *protoExts = [plugin protoExtensions];
    for (HGSProtoExtension *ext in protoExts) {
      NSNumber *enabled = [NSNumber numberWithBool:[ext isEnabled]];
      NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                            [ext displayName], kPluginNameKey,
                            enabled, kPluginEnabledKey, nil];
      [allPlugins addObject:dict];
    }
  }

  [server_ setPlugins:allPlugins];
}

- (void)updatePlugin:(NSDictionary *)pluginInfo {
  NSString *pluginName = [pluginInfo objectForKey:kPluginNameKey];
  NSNumber *state = [pluginInfo objectForKey:kPluginEnabledKey];
  NSArray *sources = [[HGSExtensionPoint pluginsPoint] extensions];
  for (HGSPlugin *plugin in sources) {
    NSArray *protoExts = [plugin protoExtensions];
    for (HGSProtoExtension *ext in protoExts) {
      NSString *currentName = [ext displayName];
      if ([currentName isEqualToString:pluginName] && [ext canSetEnabled]) {
        [ext setEnabled:[state boolValue]];
      }
    }
  }
}

#pragma mark -- HGSPluginLoader notification handlers --

- (void)pluginsDidInstall:(NSNotification *)aNotification {
  // What time did we stop loading
  NSDate *startupTime = [NSDate date];

  // Register for the search notifications
  NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];

  // Create the server.
  server_ = [[BeaconServer alloc] init];
  if (!server_) {
    // If we are unable to create the server, we are worthless so there is no
    // point in doing any work.
    HGSLog(@"There was an error creating the Transference server.  Entering a "
           @"dormant state.  Please re-launch QSB to attempt to start the "
           @"server successfully.");
    [noteCenter removeObserver:self];
  } else {
    [server_ runInCurrentThread];

    [noteCenter addObserver:self
                   selector:@selector(HGSQueryControllerWillStart:)
                       name:kHGSQueryControllerWillStartNotification
                     object:nil];

    [noteCenter addObserver:self
                   selector:@selector(HGSQueryControllerDidFinish:)
                       name:kHGSQueryControllerDidFinishNotification
                     object:nil];

    [noteCenter addObserver:self
                   selector:@selector(HGSSearchOperationWillStart:)
                       name:kHGSSearchOperationWillStartNotification
                     object:nil];

    [noteCenter addObserver:self
                   selector:@selector(HGSSearchOperationDidFinish:)
                       name:kHGSSearchOperationDidFinishNotification
                     object:nil];

    [server_ setStartupTime:startupTime];

    // The server currently runs in the same thread as the BeaconModule, but if
    // we increase the work the server has to do we may want to spin out another
    // thread.
    // TODO: If we have the server run in another thread we will need
    // to make all of the getters and setters thread safe.
    [server_ setDelegate:self];
  }
}

#pragma mark -- HGSController notification handlers --

- (void)HGSQueryControllerWillStart:(NSNotification *)aNotification {
  // New search clear out that old data
  if ([startedSearchSources_ count] > 0)
    [startedSearchSources_ removeAllObjects];

  if ([completedSearchSources_ count] > 0)
    [completedSearchSources_ removeAllObjects];

  [startSearchDate_ release];
  startSearchDate_ = nil;

  [endSearchDate_ release];
  endSearchDate_ = nil;

  // We are starting again
  startSearchDate_ = [[NSDate alloc] init];
}

- (void)HGSQueryControllerDidFinish:(NSNotification *)aNotification {
  [endSearchDate_ release];
  endSearchDate_ = nil;

  endSearchDate_ = [[NSDate alloc] init];
  NSTimeInterval searchTime =
    [endSearchDate_ timeIntervalSinceDate:startSearchDate_];

  /*
   * Keeping for future debugging.
   *
   *
  HGSLog(@"Total search time: %f", searchTime);
  HGSLog(@"Number of sources started: %d", [startedSearchSources_ count]);
  HGSLog(@"Number of sources completed: %d", [completedSearchSources_ count]);
  HGSLog(@"started sources list: %@", [startedSearchSources_ description]);
  HGSLog(@"completed sources list: %@", [completedSearchSources_ description]);
  HGSLog(@"Calculated search time: %f seconds", searchTime);
   *
   */

  // Calculate how long each source took to complete and make it available to
  // any clients.
  NSMutableArray *moduleSearchTimes = [NSMutableArray array];
  NSMutableDictionary *newItem = [NSMutableDictionary dictionaryWithCapacity:2];
  for (NSDictionary *startItem in startedSearchSources_) {
    NSString *startSourceName =
      [startItem objectForKey:kTransferenceModuleName];
    NSDate *startSourceDate = [startItem objectForKey:kTransferenceModuleTime];

    // Find this source in the completed list
    for (NSDictionary *itemToCompare in completedSearchSources_) {
      NSString *endSourceName =
        [itemToCompare objectForKey:kTransferenceModuleName];
      NSDate *endSourceDate =
        [itemToCompare objectForKey:kTransferenceModuleTime];
      if ([endSourceName isEqualToString:startSourceName]) {
        [newItem setObject:endSourceName forKey:kTransferenceModuleName];
        // Get the time interval
        NSTimeInterval timeInterval =
          [endSourceDate timeIntervalSinceDate:startSourceDate];
        // Sometimes there are duplicates in the completed list, we will only
        // pay attention to the larger times.
        if ([[newItem objectForKey:kTransferenceModuleTime] doubleValue] < timeInterval) {
          [newItem setObject:[NSNumber numberWithDouble:timeInterval]
                      forKey:kTransferenceModuleTime];
        }
      }
      if ([[newItem allKeys] count] > 0) {
        NSDictionary *dict = [NSDictionary dictionaryWithDictionary:newItem];
        [moduleSearchTimes addObject:dict];
      }

      // Start fresh
      [newItem removeAllObjects];
    }
  }

  [server_ setLastSearchTime:searchTime moduleInfo:moduleSearchTimes];

  HGSQueryController *object = [aNotification object];
  HGSTypeFilter *allFilter = [HGSTypeFilter filterAllowingAllTypes];
  NSUInteger count = [object resultCountForFilter:allFilter];
  NSArray *rankedResults = [object rankedResultsInRange:NSMakeRange(0, count)
                                             typeFilter:allFilter
                                       removeDuplicates:NO];
  [server_ setLastRankedResults:rankedResults];
}

#pragma mark -- HGSSearchOperation notification handlers --

- (void)HGSSearchOperationWillStart:(NSNotification *)aNotification {
  id searchObject = [aNotification object];
  NSDictionary *dict = [self searchSourceDictionaryForObject:searchObject];
  if (dict) {
    [startedSearchSources_ addObject:dict];
  }
}

- (void)HGSSearchOperationDidFinish:(NSNotification *)aNotification {
  id searchObject = [aNotification object];
  NSDictionary *dict = [self searchSourceDictionaryForObject:searchObject];
  if (dict) {
    [completedSearchSources_ addObject:dict];
  }
}

@end
