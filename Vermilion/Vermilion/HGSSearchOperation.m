//
//  HGSSearchOperation.m
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

#import "HGSSearchOperation.h"
#import <mach/mach_time.h>
#import "HGSSearchSource.h"
#import "HGSOperation.h"
#import "HGSLog.h"
#import "NSNotificationCenter+MainThread.h"

NSString *const kHGSSearchOperationWillStartNotification 
  = @"HGSSearchOperationWillStartNotification";
NSString *const kHGSSearchOperationDidFinishNotification 
  = @"HGSSearchOperationDidFinishNotification";
NSString *const kHGSSearchOperationDidUpdateResultsNotification 
  = @"HGSSearchOperationDidUpdateResultsNotification";
NSString *const kHGSSearchOperationWasCancelledNotification
  = @"HGSSearchOperationWasCancelledNotification";

@interface HGSSearchOperation ()
@property (assign, getter=isFinished) BOOL finished;
@end

@implementation HGSSearchOperation

@synthesize source = source_;
@synthesize query = query_;
@synthesize finished = finished_;
@synthesize runTime = runTime_;
@synthesize queueTime = queueTime_;
@dynamic concurrent;
@dynamic cancelled;

- (id)initWithQuery:(HGSQuery*)query source:(HGSSearchSource *)source {
  if ((self = [super init])) {
    source_ = [source retain];
    query_ = [query retain]; 
    if (!source_ || !query_) {
      HGSLogDebug(@"HGSSearchOperation -initWithQuery:source: nil source "
                  @"or query");
      [self release];
      self = nil;
    }
  }
  return self;
}

- (void)dealloc {
  [source_ release];
  [query_ release];
  [super dealloc];
}

- (BOOL)isConcurrent {
  return NO;
}

- (void)cancel {
  if (![self isFinished]) {
    // Even though we clear the operation here, we don't need to
    // do anything from a threading pov.  If |operation_| were in a queue to run,
    // the queue would have a retain on it, so it won't get freed from under it.
    queryCancelled_ = YES;
    [operation_ cancel];
    [operation_ release];
    operation_ = nil;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc hgs_postOnMainThreadNotificationName:kHGSSearchOperationWasCancelledNotification
                                      object:self];
  }
}

- (BOOL)isCancelled {
  // NOTE: this is thread safe because the NSOperationQueue has to retain the
  // operation while it runs.  So the fact that -cancel releases it is ok.
  return queryCancelled_ || [operation_ isCancelled];
}

- (void)wrappedMain {
  // Wrap main so we can log any exceptions and make sure we finish the search
  // operation if it threw.
  @try {
    [self main];
  }
  @catch (NSException * e) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:kHGSValidateSearchSourceBehaviorsPrefKey]) {
      HGSLog(@"ERROR: exception (%@) from SearchOperation %@", e, self);
    }
    // Make sure it's been marked as finished since it probably won't do that on
    // it's own now.
    if (![self isFinished]) {
      [self finishQuery];
    }
  }
}
  
- (void)queryOperation:(id)ignored {
  if (![self isCancelled]) {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc hgs_postOnMainThreadNotificationName:kHGSSearchOperationWillStartNotification
                                      object:self];
    runTime_ = mach_absolute_time();
    queueTime_ = runTime_ - queueTime_;
    if ([self isConcurrent]) {
      if ([NSThread currentThread] == [NSThread mainThread]) {
        [self wrappedMain];
      } else {
        // Concurrents were queued just to get things started, we bounce to the
        // main loop to actually run them (and they must call finishQuery
        // when done).
        [self performSelectorOnMainThread:@selector(wrappedMain)
                               withObject:nil
                            waitUntilDone:NO];
      }
    } else {
      // Fire it
      @try {
        [self main];
      }
      @catch (NSException * e) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults boolForKey:kHGSValidateSearchSourceBehaviorsPrefKey]) {
          HGSLog(@"ERROR: exception (%@) from SearchOperation %@", e, self);
        }
      }
      // Non concurrent ones are done when their main finishes
      [self finishQuery];
    }
  }
}

- (void)finishQuery {
  [operation_ release];
  operation_ = nil;
  if ([self isFinished]) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:kHGSValidateSearchSourceBehaviorsPrefKey]) {
      HGSLog(@"ERROR: finishedQuery called more than once for SearchOperation"
             @" %@ (if search operation is concurrent, you do NOT need to call"
             @" finishQuery).",
             self);
    }
    // Never send the notification twice
    return;
  }
  runTime_ = mach_absolute_time() - runTime_;
  [self setFinished:YES];
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc hgs_postOnMainThreadNotificationName:kHGSSearchOperationDidFinishNotification
                                    object:self];
}

- (void)main {
  // Since SearchSources are the only thing that needs to create these, we use
  // their pref for enabling extra logging to help developers out.
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults boolForKey:kHGSValidateSearchSourceBehaviorsPrefKey]) {
    HGSLog(@"ERROR: SearchOperation %@ forgot to override main.",
           [self class]);
  }
  [self doesNotRecognizeSelector:_cmd];
}

- (NSArray *)sortedRankedResultsInRange:(NSRange)range
                             typeFilter:(HGSTypeFilter *)typeFilter {
  NSMutableArray *array = nil;
  if (range.length > 0) {
    array = [NSMutableArray arrayWithCapacity:range.length];
    [self disableUpdates];
    for (NSUInteger i = range.location; i < NSMaxRange(range); ++i) {
      HGSScoredResult *result = [self sortedRankedResultAtIndex:i
                                                     typeFilter:typeFilter];
      if (result) {
        [array addObject:result];
      }
    }
    [self enableUpdates];
  }
  return array;
}

- (HGSScoredResult *)sortedRankedResultAtIndex:(NSUInteger)idx
                                    typeFilter:(HGSTypeFilter *)typeFilter  {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (NSUInteger)resultCountForFilter:(HGSTypeFilter *)filter {
  [self doesNotRecognizeSelector:_cmd];
  return 0;
}

- (NSString*)description {
  return [NSString stringWithFormat:@"%@ %@ - query: %@", 
          [super description],  
          [self isFinished] ? @"finished" : @"", query_];
}

- (NSString *)displayName {
  return NSStringFromClass([self class]);
}

- (NSOperation *)searchOperation {
  operation_ =
    [[NSInvocationOperation alloc] initWithTarget:self
                                         selector:@selector(queryOperation:)
                                           object:nil];
  return operation_;
}

- (void)runOnCurrentThread:(BOOL)onThread {
  NSOperation *operation = [self searchOperation];
  queueTime_ = mach_absolute_time();
  if (onThread) {
    [self queryOperation:nil];
  } else {
    HGSOperationQueue *queue = [HGSOperationQueue sharedOperationQueue];
    [operation setQueuePriority:NSOperationQueuePriorityVeryHigh];
    [queue addOperation:operation];
  }
}

- (void)enableUpdates {
  // Default does nothing.
}

- (void)disableUpdates {
  // Default does nothing.
}

@end
