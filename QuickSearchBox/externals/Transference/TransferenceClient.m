//
//  TransferenceClient.m
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

#import "TransferenceClient.h"

const NSTimeInterval kProcessingTimeout = 240.0;

@interface QSBPlugin ()
// Designated initializer.  Creates a QSBPlugin object with the corresponding
// dictionary and client reference.
- (id)initWithDictionary:(NSDictionary *)dict
                  client:(TransferenceClient *)client;

// Convenience initializer.
+ (id)pluginWithDictionary:(NSDictionary *)dict
                    client:(TransferenceClient *)client;
@end

@interface QSBResult ()
// Designated initializer.  Creates a QSBResult object with the corresponding
// dictionary and client reference.
- (id)initWithDictionary:(NSDictionary *)dict
                  client:(TransferenceClient *)client;

// Convenience initializer.
+ (id)resultWithDictionary:(NSDictionary *)dict
                    client:(TransferenceClient *)client;
@end

@interface TransferenceClient ()
// Changes the state of the plugin of the given name to the given state.
- (void)setStateOfPlugin:(NSString *)name state:(NSNumber *)state;

// Performs the action with the given name to the given result.
- (BOOL)performAction:(NSString *)actionName onResult:(NSDictionary *)result;

// Performs a search with the Quick Search Box using the AppleScript interface.
// If wait is equal to YES then this function will be performed synchronously;
// otherwise it will be performed asynchronously.
- (void)performSearch:(NSString *)query waitUntilComplete:(BOOL)performWait;

// Take the results from the server and converts them into an array of
// QSBResult objects.
- (NSArray *)generateQSBResults:(NSArray *)originalResults;

// Spins and waits for resultsProcessed_ to be returned as YES or for a limit of
// kProcessingTimeout.
- (BOOL)waitForResultProcessing;
@end

@implementation TransferenceClient

#pragma mark -- Initialize and Dealloc --

+ (id)clientWithAddress:(NSString *)address {
  return [[[self alloc] initWithAddress:address] autorelease];
}

+ (id)clientWithAddress:(NSString *)address port:(unsigned short)port {
  return [[[self alloc] initWithAddress:address port:port] autorelease];
}

+ (id)localClient {
  return [[[self alloc] initWithAddress:@"localhost"] autorelease];
}

- (id)initWithAddress:(NSString *)address {
  return [self initWithAddress:address port:kTransferencePort];
}

- (id)initWithAddress:(NSString *)address port:(unsigned short)port {
  if ((self = [super init])) {
    // Build a socket we need to connect to the server.
    NSSocketPort *clientSocket =
      [[NSSocketPort alloc] initRemoteWithTCPPort:port host:address];
    // Check if socket returned is valid.
    if (clientSocket) {
      // Create the proxy for server using the GMTransientRootSocketProxy
      proxy_ =
        [[GTMTransientRootPortProxy alloc] initWithReceivePort:nil
                                                      sendPort:clientSocket
                                                      protocol:@protocol(TransferenceServerProtocol)
                                                requestTimeout:kMaxTimeout
                                                  replyTimeout:kMaxTimeout];
      [clientSocket release];
      int serverProtocolVersion = [[proxy_ serverVersionNumber] intValue];
      if (serverProtocolVersion != kProtocolVersion) {
        [self release];
        self = nil;
      }
    } else {
      [clientSocket release];
      [self release];
      self = nil;
    }
  }
  return self;
}

- (void)dealloc {
  [query_ release];
  [proxy_ release];
  [super dealloc];
}

#pragma mark -- Protected Methods --

- (void)setStateOfPlugin:(NSString *)name state:(NSNumber *)state {
  [proxy_ setState:state forPlugin:name];
}

- (BOOL)performAction:(NSString *)actionName onResult:(NSDictionary *)result {
  NSMutableDictionary *dict =
    [NSMutableDictionary dictionaryWithDictionary:result];
  if (query_) {
    [dict setObject:query_ forKey:kActionQueryStringKey];
  }
  return [[proxy_ performAction:actionName onResult:dict] boolValue];
}

#pragma mark -- Private Methods --

- (void)performSearch:(NSString *)query waitUntilComplete:(BOOL)performWait {
  NSString *script = [NSString stringWithFormat:@"tell application \"Quick"
                      @" Search Box\" to search for \"%@\"", query];
  NSArray *args = [NSArray arrayWithObjects:@"-e", script, nil];

  [query_ release];
  query_ = [query retain];

  if (!performWait) {
    [NSTask launchedTaskWithLaunchPath:@"/usr/bin/osascript"
                             arguments:args];
  } else {
    NSTask *task = [[[NSTask alloc] init] autorelease];
    [task setLaunchPath:@"/usr/bin/osascript"];
    [task setArguments:args];
    NSPipe *readPipe = [NSPipe pipe];
    NSFileHandle *readHandle = [readPipe fileHandleForReading];
    NSData *inData = nil;
    [task setStandardOutput:readPipe];
    [task launch];

    while ((inData = [readHandle availableData]) && [inData length]) {
      // Drop it on the floor so it doesn't make its way to standard out
    }
    // Clear the zombie processes
    [[NSRunLoop currentRunLoop] runUntilDate:
     [NSDate dateWithTimeIntervalSinceNow:0.0]];
  }
}

- (NSArray *)generateQSBResults:(NSArray *)originalResults {
  NSMutableArray *returnArray =
    [NSMutableArray arrayWithCapacity:[originalResults count]];
  for (NSDictionary *dict in originalResults) {
    QSBResult *newResult = [QSBResult resultWithDictionary:dict client:self];
    [returnArray addObject:newResult];
  }
  return returnArray;
}

- (BOOL)waitForResultProcessing {
  NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:kProcessingTimeout];
  while (!resultsProcessed_ &&
         ([timeout compare:[NSDate date]] == NSOrderedDescending)) {
    NSDate *spinTime = [NSDate dateWithTimeIntervalSinceNow:2.0];
    [[NSRunLoop currentRunLoop] runUntilDate:spinTime];
  }
  return resultsProcessed_;
}

#pragma mark -- Public Methods (TransferenceClientProtocol) --

- (oneway void)searchCompleted {
  [delegate_ performSelector:@selector(searchDidComplete)];
}

- (oneway void)rankedResults:(in bycopy NSArray *)results {
  [results_ release];
  results_ = [results retain];
  resultsProcessed_ = YES;
}

#pragma mark  -- Public Methods --

- (NSDate *)startupTime {
  return [[proxy_ generalStats] objectForKey:kStartupTimeKey];
}

- (NSString *)QSBVersion {
  return [[proxy_ generalStats] objectForKey:kQSBVersionKey];
}

- (NSString *)hostMacOSXVersionString {
  return [[proxy_ generalStats] objectForKey:kMacOSXVersionKey];
}

- (NSString *)hostArchitecture {
  return [[proxy_ generalStats] objectForKey:kArchitectureTypeKey];
}

- (NSTimeInterval)lastSearchTime {
  return [[[proxy_ lastSearchStats] objectForKey:kSearchTimeKey] doubleValue];
}

- (NSArray *)lastSearchResultsRanked {
  resultsProcessed_ = NO;
  [proxy_ lastSearchResultsRanked:self];
  BOOL success = [self waitForResultProcessing];
  NSArray *results = nil;
  if (success) {
    results = [self generateQSBResults:results_];
  }
  return results;
}

- (NSArray *)moduleSearchTimes {
  return [[proxy_ lastSearchStats] objectForKey:kSearchModuleTimesKey];
}

- (NSInteger)numberOfSearchResults {
  return [[proxy_ numberOfResults] integerValue];
}

- (void)performAsynchronousSearch:(NSString *)query {
  [self performSearch:query waitUntilComplete:NO];
}

- (void)performSynchronousSearch:(NSString *)query {
  [self performSearch:query waitUntilComplete:YES];
}

- (void)performSynchronousUnicodeSearch:(NSString *)query {
  NSString *script =
    [NSString stringWithFormat:
     @"tell application \"Quick Search Box\" to search for \"%@\"", query]; 
  NSAppleScript *handler = [[NSAppleScript alloc] initWithSource:script];
  [handler autorelease];
  [handler executeAndReturnError:nil];
}

- (NSArray *)plugins {
  NSArray *pluginList = [proxy_ plugins];
  NSMutableArray *returnArray =
    [NSMutableArray arrayWithCapacity:[pluginList count]];
  for (NSDictionary *dict in pluginList) {
    QSBPlugin *newPlugin = [QSBPlugin pluginWithDictionary:dict client:self];
    [returnArray addObject:newPlugin];
  }

  return returnArray;
}

- (NSData *)pluginsArchive {
  NSArray *pluginList = [proxy_ plugins];
  return [NSArchiver archivedDataWithRootObject:pluginList];
}

- (void)setPluginsUsingData:(NSData *)pluginsArchive {
  NSArray *pluginList = [NSUnarchiver unarchiveObjectWithData:pluginsArchive];
  for (NSDictionary *plugin in pluginList) {
    if ([plugin objectForKey:kPluginNameKey] &&
        [plugin objectForKey:kPluginEnabledKey]) {
      // If there are additional keys we don't care these are the only two we
      // will use
        [proxy_ setState:[plugin objectForKey:kPluginEnabledKey]
               forPlugin:[plugin objectForKey:kPluginNameKey]];
    }
  }
}

- (void)subscribeToServer {
  [proxy_ subscribeClient:self];
}

- (void)unsubscribeFromServer {
  [proxy_ unsubscribeClient:self];
}

- (void)setDelegate:(id)delegate {
  delegate_ = delegate;
}

- (BOOL)isConnected {
  return [proxy_ isConnected];
}
@end

@implementation QSBPlugin

#pragma mark -- Initialize and Dealloc --

- (id)initWithDictionary:(NSDictionary *)dict
                  client:(TransferenceClient *)client {
  if ((self = [super init])) {
    NSString *name = [dict objectForKey:kPluginNameKey];
    if ((!name) || (!client)) {
      [self release];
      self = nil;
      return self;
    }
    pluginName_ = [[NSString alloc] initWithString:name];
    enabled_ = NO;
    if ([dict objectForKey:kPluginEnabledKey]) {
      enabled_ = [[dict objectForKey:kPluginEnabledKey] boolValue];
    }
    // Get a pointer to the client
    client_ = client;
  }
  return self;
}

- (id)init {
  return [self initWithDictionary:nil client:nil];
}

+ (id)pluginWithDictionary:(NSDictionary *)dict
                    client:(TransferenceClient *)client {
  return [[[self alloc] initWithDictionary:dict client:client] autorelease];
}

- (void)dealloc {
  [pluginName_ release];
  [super dealloc];
}

#pragma mark -- Public Methods --

- (NSString *)displayName {
  return pluginName_;
}

- (BOOL)enabled {
  return enabled_;
}

- (void)setEnabled:(BOOL)enabled {
  // Transference will not allow dependent apps to disconnect it from QSB
  if (![pluginName_ isEqualToString:@"Transference Beacon"]) {
    [client_ setStateOfPlugin:pluginName_
                        state:[NSNumber numberWithBool:enabled]];
  }
}
@end

@implementation QSBResult

#pragma mark -- Initialize and Dealloc --

- (id)initWithDictionary:(NSDictionary *)dict
                  client:(TransferenceClient *)client {
  if ((self = [super init])) {
    if (!client) {
      [self release];
      self = nil;
      return self;
    }

    NSArray *actions = [dict objectForKey:kResultAvailableActionsKey];
    if (actions) {
      availableActions_ =
        [[NSMutableArray alloc] initWithCapacity:[actions count]];
      for (NSDictionary *currentDict in actions) {
        NSString *actionName =
          [currentDict objectForKey:kResultActionDisplayNameKey];
        [availableActions_ addObject:actionName];
      }
    }

    serverData_ = [[NSDictionary alloc] initWithDictionary:dict];
    // Get a pointer to the client
    client_ = client;
  }
  return self;
}

- (id)init {
  return [self initWithDictionary:nil client:nil];
}

+ (id)resultWithDictionary:(NSDictionary *)dict
                    client:(TransferenceClient *)client {
  return [[[self alloc] initWithDictionary:dict client:client] autorelease];
}

- (void)dealloc {
  [serverData_ release];
  [availableActions_ release];
  [super dealloc];
}

#pragma mark -- Public Methods --

- (NSString *)displayName {
  return [serverData_ objectForKey:kResultDisplayNameKey];
}

- (NSString *)displayPath {
  return [serverData_ objectForKey:kResultDisplayPathKey];;
}

- (NSArray *)availableActions {
  return availableActions_;
}

- (BOOL)performAction:(NSString *)actionName {
  return [client_ performAction:actionName onResult:serverData_];
}

@end
