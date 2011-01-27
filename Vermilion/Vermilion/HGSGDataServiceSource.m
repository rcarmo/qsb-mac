//
//  HGSGDataServiceSource.m
//
//  Copyright (c) 2008 Google Inc. All rights reserved.
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

#import "HGSGDataServiceSource.h"
#import <GData/GData.h>
#import "HGSLog.h"
#import "HGSKeychainItem.h"
#import "HGSOperation.h"

NSString *const kHGSGDataServiceSourceRefreshIntervalKey
  = @"HGSGDataServiceSourceRefreshIntervalKey";
NSString *const kHGSGDataServiceSourceRefreshJitterKey
  = @"HGSGDataServiceSourceRefreshJitterKey";
NSString *const kHGSGDataServiceSourceErrorReportingIntervalKey
  = @"HGSGDataServiceSourceErrorReportingIntervalKey";


@interface NSError (GoogleCalendarsSource)

// Create a new error by adding a fetch type to an existing errors userInfo.
- (NSError *)hgs_errorByAddingFetchType:(NSString *)fetchType;

@end

@interface HGSGDataServiceSource ()
- (void)setUpPeriodicRefresh:(NSTimeInterval)interval
                  withJitter:(NSTimeInterval)jitter;
- (void)loginCredentialsChanged:(NSNotification *)notification;
- (void)refreshIndex:(NSTimer*)timer;
@end

@implementation HGSGDataServiceSource

@synthesize account = account_;
@synthesize service = service_;

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {

    account_ = [[configuration objectForKey:kHGSExtensionAccountKey] retain];
    NSNumber *number
      = [configuration objectForKey:kHGSGDataServiceSourceRefreshIntervalKey];
    if (number) {
      refreshInterval_ = [number doubleValue];
    }
    if (!(refreshInterval_ > 0)) {
      refreshInterval_ = 300.0;  // 5 minutes
    }
    number
      = [configuration objectForKey:kHGSGDataServiceSourceRefreshIntervalKey];
    if (number) {
      refreshJitter_ = [number doubleValue];
    }
    if (!(refreshJitter_ > 0)) {
      refreshJitter_ = 300.0;  // 5 minutes
    }
    number
      = [configuration objectForKey:kHGSGDataServiceSourceErrorReportingIntervalKey];
    if (number) {
      errorReportingInterval_ = [number doubleValue];
    }
    if (!(refreshJitter_ > 0)) {
      errorReportingInterval_ = 3600.0;  // 60 minutes
    }

    if (account_) {
      // Watch for credential changes.
      NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
      [nc addObserver:self
             selector:@selector(loginCredentialsChanged:)
                 name:kHGSAccountDidChangeNotification
               object:account_];
      [self setUpPeriodicRefresh:0 withJitter:0];
    } else {
      HGSLogDebug(@"Missing account identifier for %@ '%@'",
                  [self class], [self identifier]);
      [self release];
      self = nil;
    }
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  _GTMDevAssert(!indexOp_ || [indexOp_ isCancelled], NULL);
  [service_ release];
  [account_ release];
  [updateTimer_ release];
  [indexOp_ release];
  [super dealloc];
}

- (void)uninstall {
  [indexOp_ cancel];
  [updateTimer_ invalidate];
  [super uninstall];
}

#pragma mark -
#pragma mark Album Fetching

- (void)asyncFetch:(GDataServiceGooglePhotos *)service operation:(NSOperation *)op{
  GDataServiceTicket *ticket = [self fetchTicketForService:service];
  HGSMemorySearchSourceDB *database = [HGSMemorySearchSourceDB database];
  HGSGDataServiceIndexContext *context
    = [[[HGSGDataServiceIndexContext alloc] initWithOperation:op
                                                      service:service
                                                     database:database]
       autorelease];
  [context addTicket:ticket];
  [ticket setUserData:context];
  CFRunLoopSourceContext rlContext;
  bzero(&rlContext, sizeof(rlContext));
  CFRunLoopSourceRef source = CFRunLoopSourceCreate(NULL, 0, &rlContext);
  CFRunLoopRef runloop = CFRunLoopGetCurrent();
  CFRunLoopAddSource(runloop, source, kCFRunLoopDefaultMode);
  while (![context isFinished]) {
    CFRunLoopRun();
  }
  CFRunLoopRemoveSource(runloop, source, kCFRunLoopDefaultMode);
  CFRelease(source);
  if (![context isCancelled]) {
    [self replaceCurrentDatabaseWith:database];
  }
  // If we finished successfully, the below should be a no-op.
  [context cancelTickets];
}

- (void)ticketHandled:(GDataServiceTicket *)ticket
           forContext:(HGSGDataServiceIndexContext *)context {
  [context removeTicket:ticket];
  CFRunLoopStop(CFRunLoopGetCurrent());
}

- (void)setUpPeriodicRefresh {
  [self setUpPeriodicRefresh:refreshInterval_ withJitter:refreshJitter_];
}

- (void)setUpPeriodicRefresh:(NSTimeInterval)interval
                  withJitter:(NSTimeInterval)jitterRange {
  [updateTimer_ invalidate];
  [updateTimer_ release];
  // We add 5 minutes worth of random jitter.
  if (interval > 0) {
    interval += arc4random() / (LONG_MAX / jitterRange);
  }
  updateTimer_
    = [[NSTimer scheduledTimerWithTimeInterval:interval
                                        target:self
                                      selector:@selector(refreshIndex:)
                                      userInfo:nil
                                       repeats:NO] retain];
}

- (void)refreshIndex:(NSTimer*)timer {
  if (!service_) {
    HGSKeychainItem* keychainItem
      = [HGSKeychainItem keychainItemForService:[account_ identifier]
                                     username:nil];
    NSString *username = [keychainItem username];
    NSString *password = [keychainItem password];
    if ([username length]) {
      service_ = [[[self serviceClass] alloc] init];
      [service_ setUserAgent:@"google-qsb-1.0"];
      // If there is no password then we will only fetch public albums.
      if ([password length]) {
        [service_ setUserCredentialsWithUsername:username
                                        password:password];
      }
      [service_ setServiceShouldFollowNextLinks:YES];
      [service_ setIsServiceRetryEnabled:YES];
    } else {
      [updateTimer_ invalidate];
      return;
    }
  }
  [indexOp_ cancel];
  [indexOp_ release];
  indexOp_
    = [[HGSInvocationOperation alloc] initWithTarget:self
                                            selector:@selector(asyncFetch:operation:)
                                              object:service_];
  [[HGSOperationQueue sharedOperationQueue] addOperation:indexOp_];

  [self setUpPeriodicRefresh];
}

- (void)loginCredentialsChanged:(NSNotification *)notification {
  HGSAssert([notification object] == account_,
            @"Notification from unexpected account!");
  // If we're in the middle of a fetch then cancel it first.
  [indexOp_ cancel];

  // Clear the service so that we make a new one with the correct credentials.
  [service_ release];
  service_ = nil;
  // If the login changes, we should update immediately, and make sure the
  // periodic refresh is enabled (it would have been shut down if the previous
  // credentials were incorrect).
  [self setUpPeriodicRefresh:0 withJitter:0];
}

- (void)handleErrorForFetchType:(NSString *)fetchType
                          error:(NSError *)error {
  NSInteger errorCode = [error code];
  if (errorCode != kGDataHTTPFetcherStatusNotModified) {
    // Don't report not-connected errors.
    if (errorCode == kGDataBadAuthentication) {
      // If the login credentials are bad, don't keep trying.
      [updateTimer_ invalidate];
      [updateTimer_ release];
      updateTimer_ = nil;
      // Tickle the account so that if the user happens to have the preference
      // window open showing either the account or the search source they
      // will immediately see that the account status has changed.
      [account_ authenticate];
    }
    if (errorCode != NSURLErrorNotConnectedToInternet) {
      NSError *fetchError = [error hgs_errorByAddingFetchType:fetchType];
      NSTimeInterval currentTime = [[NSDate date] timeIntervalSinceReferenceDate];
      NSTimeInterval timeSinceLastErrorReport
        = currentTime - previousErrorReportingTime_;
      if (timeSinceLastErrorReport > errorReportingInterval_) {
        previousErrorReportingTime_ = currentTime;
        NSString *errorString = nil;
        if (errorCode == 404) {
          errorString = @"might not be enabled";
        } else {
          errorString = @"fetch failed";
        }
        HGSLog(@"%@ (%@InfoFetcher) %@ for account '%@': "
               @"error=%d '%@'.", [self class], fetchType, errorString,
               [account_ displayName], errorCode, [fetchError localizedDescription]);
      }
    }
  }
}

- (GDataServiceTicket *)fetchTicketForService:(GDataServiceGoogle *)service {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (Class)serviceClass {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

#pragma mark -
#pragma mark HGSAccountClientProtocol Methods

- (BOOL)accountWillBeRemoved:(HGSAccount *)account {
  HGSAssert(account == account_, @"Notification from bad account!");

  // Cancel any outstanding fetches.
  [indexOp_ cancel];

  // And get rid of the service.
  [service_ release];
  service_ = nil;

  return YES;
}

@end

#pragma mark -

@implementation HGSGDataServiceIndexContext

@synthesize service = service_;
@synthesize database = database_;

- (id)initWithOperation:(NSOperation *)operation
                service:(GDataServiceGoogle *)service
               database:(HGSMemorySearchSourceDB *)database {
  if ((self = [super init])) {
    operation_ = [operation retain];
    service_ = [service retain];
    tickets_ = [[NSMutableArray alloc] init];
    database_ = [database retain];
  }
  return self;
}

- (void)dealloc {
  [operation_ release];
  [tickets_ release];
  [service_ release];
  [database_ release];
  [super dealloc];
}

- (void)addTicket:(GDataServiceTicket *)ticket {
  [tickets_ addObject:ticket];
}

- (void)removeTicket:(GDataServiceTicket *)ticket {
  [tickets_ removeObject:ticket];
}

- (void)cancelTickets {
  [tickets_ makeObjectsPerformSelector:@selector(cancelTicket)];
}

- (BOOL)isFinished {
  return ([self isCancelled]) || ([tickets_ count] == 0);
}

- (BOOL)isCancelled {
  return [operation_ isCancelled];
}

@end

#pragma mark -

// This is a key for the fetch type that we add to the userInfo of NSErrors
// when errors occur in fetches.
static NSString *const kGoogleFetchTypeErrorKey = @"GoogleFetchType";

@implementation NSError (HGSGDataServiceSource)

- (NSError *)hgs_errorByAddingFetchType:(NSString *)fetchType {
  NSMutableDictionary *userInfo
  = [NSMutableDictionary dictionaryWithDictionary:[self userInfo]];
  [userInfo setObject:fetchType forKey:kGoogleFetchTypeErrorKey];
  return [NSError errorWithDomain:[self domain]
                             code:[self code]
                         userInfo:userInfo];
}

@end
