//
//  BeaconServer.m
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

// Required for DO communication
#include <sys/socket.h>

// Needed to get the socket port.
#import <netinet/in.h>
#import <arpa/inet.h>

// Needed to get the value of global variable errno
#import <errno.h>

// Other imports
#import "GTMSystemVersion.h"
#import "QSBApplicationDelegate.h"
#import "QSBSearchWindowController.h"
#import "QSBSearchController.h"
#import "QSBResultsWindowController.h"
#import "Shortcuts.h"

static NSString *const kPrefsPath =
  @"Preferences/com.google.qsb.module.transferencebeacon.plist";

static NSString *const kServerPortKey = @"serverPort";

// Internal result keys that are only used on the server side
static NSString *const kResultHGSResultKey = @"ResultHGSResult";
static NSString *const kResultActionKey = @"ResultAction";

@interface BeaconServer ()
// Returns the general stats dictionary, if it does not exist it is created.
// The reason for this is we don't want to obtain this information on load.  The
// longer it takes us to load the longer the QSB takes to load.  So we don't
// don't want to do any work until after the QSB is loaded.
- (NSDictionary *)generateGeneralStats;

// Converts results passed from the BeaconModule into an NSDictionary that can
// be used without access to Vermillion.  The resulting array is what will be
// sent to the client.
- (NSArray *)convertResultsToTransferenceResults:(NSArray *)results;
@end

@implementation BeaconServer

@synthesize delegate = delegate_;
@synthesize startupTime = startupTime_;

#pragma mark -- Initialize and Dealloc --

- (id)init {
  unsigned short defaultPort = kTransferencePort;

  // The default can be overriden if the correct key is in place
  NSArray *library = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                         NSUserDomainMask,
                                                         YES);
  if ([library count] > 0) {
    NSString *prefsPath =
      [[library objectAtIndex:0] stringByDeletingLastPathComponent];
    prefsPath = [prefsPath stringByAppendingPathComponent:kPrefsPath];
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:prefsPath];
    NSNumber *port = [prefs objectForKey:kServerPortKey];
    if (port)
      defaultPort = [port unsignedShortValue];
  }

  // We want to tell the socket to use SO_REUSEADDR so we can quickly use
  // this port again.
  NSSocketNativeHandle sockHandle = socket(AF_INET, SOCK_STREAM, 0);
  struct sockaddr_in serverAddress;
  size_t namelen = sizeof(serverAddress);
  bzero(&serverAddress, namelen);
  serverAddress.sin_family = AF_INET;
  serverAddress.sin_addr.s_addr = htonl(INADDR_ANY);
  serverAddress.sin_port = htons(defaultPort);

  if (fcntl(sockHandle, F_SETFD, 1) == -1) {
    HGSLog(@"Transference Server: There was an error running file control.  "
           @"Message=%s", strerror(errno));
    return nil;
  }

  int flag = 1;
  if (setsockopt(sockHandle, SOL_SOCKET, SO_REUSEADDR, &flag,
                 (socklen_t)sizeof(flag))
      != noErr) {
    HGSLog(@"Transference Server: There was an error setting the socket "
           @"options.  Message=%s", strerror(errno));
    return nil;
  }

  if (bind(sockHandle, (struct sockaddr *)&serverAddress,
           (socklen_t)namelen) != noErr) {
    HGSLog(@"Transference Server: There was a problem binding to the socket.  "
           @"Message=%s", strerror(errno));
    return nil;
  }

  if (listen(sockHandle, 128) != noErr) {
    HGSLog(@"Transference Server: There was an error running listen.  "
           @"Message=%s", strerror(errno));
    return nil;
  }

  NSSocketPort *listenSocket = nil;
  listenSocket = [[NSSocketPort alloc] initWithProtocolFamily:AF_INET
                                                   socketType:SOCK_STREAM
                                                     protocol:IPPROTO_TCP
                                                       socket:sockHandle];
  [listenSocket autorelease];
  if (!listenSocket)
    return nil;

  return [self initWithSocket:listenSocket];
}

- (id)initWithSocket:(NSSocketPort *)listenSocket {
  // listenSocket is retained and released by the super class
  NSTimeInterval timeStamp = [[NSDate date] timeIntervalSinceReferenceDate];

  // The NSSocketPortServer takes a while to flush out registered names after
  // their corresponding connections have gone down.  While a failure doesn't
  // stop us from working it puts a distressing message in the log.  This
  // eliminates the message.  NSSocketPort clients connect via IP and port and
  // do not use the name.  We only need it to appease the GTMAbstractDOListener.
  NSString *serverName =
    [@"TransferenceServer" stringByAppendingFormat:@"%f", timeStamp];
  self = [super initWithRegisteredName:serverName
                              protocol:@protocol(TransferenceServerProtocol)
                                  port:listenSocket];

  if (!self) {
    HGSLog(@"Transference Server: Failed to create server");
    return nil;
  }

  [self setReplyTimeout:kMaxTimeout];
  [self setRequestTimeout:kMaxTimeout];

  // Set the startup time to 1 January 2001
  startupTime_ = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate:0];

  lastSearchStats_ = [[NSMutableDictionary alloc] init];
  clients_ = [[NSMutableArray alloc] init];

  return self;
}

- (void)dealloc {
  [startupTime_ release];
  [generalStats_ release];
  [lastSearchStats_ release];
  [clients_ release];
  [lastSearchResultsRanked_ release];
  [super dealloc];
}

#pragma mark -- Action Notification Handlers --

- (void)hgsActionWillPerform:(NSNotification *)aNotification {
  actionWillBePerformed_ = YES;
}

#pragma mark -- Private Methods --

- (NSDictionary *)generateGeneralStats {
  // Check if we already created this object.
  if (!generalStats_) {
    // Get the QSB version
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    [workspace findApplications];
    NSString *path =
      [workspace absolutePathForAppBundleWithIdentifier:@"com.google.qsb"];
    NSBundle *bundle = [NSBundle bundleWithPath:path];
    NSString *version =
      [bundle objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];

    // Get the Mac OS X version
    SInt32 major;
    SInt32 minor;
    SInt32 bugFix;
    [GTMSystemVersion getMajor:&major minor:&minor bugFix:&bugFix];
    NSString *OSString = [NSString stringWithFormat:@"%d.%d.%d", major, minor,
                          bugFix];

    // Create the string based on architecture value
    NSString *systemArchitectureString = @"Unknown";
    NSString *GTMArch = [GTMSystemVersion runtimeArchitecture];
    if ([GTMArch isEqualToString:kGTMArch_ppc] ||
        [GTMArch isEqualToString:kGTMArch_ppc64]) {
      systemArchitectureString = @"PowerPC";
    } else if ([GTMArch isEqualToString:kGTMArch_i386] ||
               [GTMArch isEqualToString:kGTMArch_x86_64]) {
      systemArchitectureString = @"Intel";
    }

    // Build the generalStats dictionary we will use from here on out
    generalStats_ =
      [[NSDictionary alloc] initWithObjectsAndKeys:
       startupTime_, kStartupTimeKey,
       OSString, kMacOSXVersionKey,
       version, kQSBVersionKey,
       systemArchitectureString, kArchitectureTypeKey, nil];
  }

  return generalStats_;
}

- (NSArray *)convertResultsToTransferenceResults:(NSArray *)results {
  NSMutableArray *returnResults 
    = [NSMutableArray arrayWithCapacity:[results count]];
  // When we send results to the client we want them to be in simple objects.
  // This avoids us from requiring the Vermillion framework on both ends.  What
  // we are going to do is break out the information the client is interested
  // in.  Here is what a single result is going to look like:
  // ------------------------------------------------------------------
  // | NSDictionary                                                   |
  // ------------------------------------------------------------------
  // | NSString* kResultDisplayNameKey : name of result               |
  // ------------------------------------------------------------------
  // | NSString* kResultDisplayPathKey : path of result               |
  // ------------------------------------------------------------------
  // | NSArray*  kResultAvailableActionsKey : available actions       |
  // ------------------------------------------------------------------
  //    | NSDictionary                                                |
  //    ---------------------------------------------------------------
  //    | NSString* kResultActionDisplayNameKey : name of action      |
  //    ---------------------------------------------------------------
  //    | HGSAction* kResultActionKey** : action object               |
  // ------------------------------------------------------------------
  // | HGSResult* kResultHGSResultKey** : result object               |
  // ------------------------------------------------------------------
  //
  // Keys denoted with ** are not available to the client.  We will need that
  // data here in the server if we need to execute the action.
  NSArray *actions = [[HGSExtensionPoint actionsPoint] extensions];
  for (HGSResult *current in results) {
    NSURL *url = [current url];
    NSString *displayName = [current displayName];
    NSString *path = [url isFileURL] ? [url path] : [url absoluteString];
    NSMutableDictionary *newDict =
    [NSMutableDictionary dictionaryWithObjectsAndKeys:
     displayName, kResultDisplayNameKey,
     path, kResultDisplayPathKey,
     nil];

    NSMutableArray *supportedActions = [NSMutableArray array];
    // Add the name of all applicable actions
    for (HGSAction *action in actions) {
      if ([action appliesToResult:current]) {
        NSDictionary *actionInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [action displayName],
                                    kResultActionDisplayNameKey,
                                    action, kResultActionKey, nil];
        [supportedActions addObject:actionInfo];
      }
    }

    if ([supportedActions count] > 0) {
      [newDict setObject:supportedActions forKey:kResultAvailableActionsKey];
    }

    [newDict setObject:current forKey:kResultHGSResultKey];
    [returnResults addObject:newDict];
  }
  return returnResults;
}

#pragma mark -- Public Methods --

- (void)setPlugins:(NSArray *)plugins {
  if (plugins_ != plugins) {
    [plugins_ release];
    plugins_ = [plugins retain];
  }
}

- (void)setLastSearchTime:(NSTimeInterval)searchTime
               moduleInfo:(NSArray *)info {
  [lastSearchStats_ setObject:[NSNumber numberWithDouble:searchTime]
                       forKey:kSearchTimeKey];

  if (info) {
    [lastSearchStats_ setObject:info forKey:kSearchModuleTimesKey];
  }

  // A search just completed, tell all registered clients that it is done
  for (id currentClient in clients_) {
    @try {
      [currentClient searchCompleted];
    }
    @catch (NSException *e) {
      HGSLog(@"Transference Beacon: Exception thown when notifying a client "
             @"that a search completed.  They probably disconnected without "
             @"unsubscribing.  Error: %@", e);
    }
  }
}

- (void)setLastRankedResults:(NSArray *)results {
  [lastSearchResultsRanked_ release];
  lastSearchResultsRanked_ = [results retain];
}

#pragma mark -- Implementation of TransferenceServerProtocol --

- (bycopy NSDictionary *)generalStats {
  return [self generateGeneralStats];
}

- (bycopy NSDictionary *)lastSearchStats {
  return lastSearchStats_;
}

- (in bycopy NSNumber *)numberOfResults {
  return [NSNumber numberWithInteger:[lastSearchResultsRanked_ count]];
}

- (oneway void)lastSearchResultsRanked:(in byref id <TransferenceClientProtocol>)client {
  NSArray *returnArray = nil;
  if ([lastSearchResultsRanked_ count] > 0) {
    returnArray =
      [self convertResultsToTransferenceResults:lastSearchResultsRanked_];
  }

  [client rankedResults:returnArray];
}

- (in bycopy NSNumber *)performAction:(NSString *)actionName
                             onResult:(NSDictionary *)dict {
  NSArray *actions = [dict objectForKey:kResultAvailableActionsKey];
  HGSAction *action = nil;
  for (NSDictionary *currentAction in actions) {
    NSString *name = [currentAction objectForKey:kResultActionDisplayNameKey];
    if ([name isEqualToString:actionName]) {
      action = [currentAction objectForKey:kResultActionKey];
      break;
    }
  }

  if (!action) {
    return [NSNumber numberWithBool:NO];
  }

  HGSResult *result = [dict objectForKey:kResultHGSResultKey];
  HGSResultArray *resultArray = [HGSResultArray arrayWithResult:result];
  NSDictionary *arguments 
    = [NSDictionary dictionaryWithObject:resultArray 
                                  forKey:kHGSActionDirectObjectsKey];
  HGSActionOperation *operation =
    [[[HGSActionOperation alloc] initWithAction:action
                                      arguments:arguments] autorelease];

  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self
         selector:@selector(hgsActionWillPerform:)
             name:kHGSActionWillPerformNotification
           object:nil];

  actionWillBePerformed_ = NO;
  [operation performAction];

  // We don't want this to cause us to be disconnected
  NSDate *startDate = [NSDate date];
  NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
  while (!actionWillBePerformed_ &&
         ([startDate timeIntervalSinceNow] > -(kMaxTimeout / 2.0))) {
    [runLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
  }

  BOOL skipShortcutNotification = [[result source] cannotArchive];
  NSString *queryString = [dict objectForKey:kActionQueryStringKey];
  if (actionWillBePerformed_ && queryString && !skipShortcutNotification) {
    // Apply the execution of the action to the shortcuts database using
    // a backdoor.
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              result, kShortcutsResultKey,
                              queryString, kShortcutsShortcutKey,
                              nil];
    [nc postNotificationName:kShortcutsUpdateShortcutNotification
                      object:self
                    userInfo:userInfo];
  }
  return [NSNumber numberWithBool:actionWillBePerformed_];
}

- (in bycopy NSArray *)plugins {
  NSArray *returnArray = nil;
  [delegate_ performSelector:@selector(refreshPlugins) withObject:nil];
  if ([plugins_ count] > 0) {
    returnArray = plugins_;
  }
  return returnArray;
}

- (in bycopy NSNumber *)serverVersionNumber {
  return [NSNumber numberWithInt:kProtocolVersion];
}

- (void)setState:(NSNumber *)state forPlugin:(NSString *)pluginName {
  NSDictionary *object =
    [NSDictionary dictionaryWithObjectsAndKeys:state, kPluginEnabledKey,
                                                pluginName, kPluginNameKey,
                                                nil];
  [delegate_ performSelector:@selector(updatePlugin:) withObject:object];
}

- (void)subscribeClient:(in byref id <TransferenceClientProtocol>)newClient {
  // All of the clients will be maintained in an array.
  [clients_ addObject:newClient];
}

- (void)unsubscribeClient:(in byref id <TransferenceClientProtocol>)client {
  [clients_ removeObject:client];
}

@end
